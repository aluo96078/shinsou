import CloudKit
import ShinsouDomain

/// CloudKit 同步引擎：負責推送本機變更到雲端、拉取雲端變更到本機。
/// 使用 CKFetchRecordZoneChangesOperation 進行增量拉取（相容 iOS 16）。
@MainActor
final class CloudKitSyncEngine {

    static let shared = CloudKitSyncEngine()

    private let zoneManager = CloudKitZoneManager.shared
    private let changeTracker = CloudKitChangeTracker.shared

    /// Debounce 用的推送任務
    private var pushDebounceTask: Task<Void, Never>?

    /// 取得可用的 CKDatabase，不可用時拋出錯誤。
    private func requireDatabase() throws -> CKDatabase {
        let container = try zoneManager.requireContainer()
        return container.privateCloudDatabase
    }

    private init() {}

    // MARK: - Full Sync

    /// 執行完整同步：先推送本機變更，再拉取雲端變更。
    func sync() async throws {
        // 確保 Zone 與 Subscription 存在
        try await zoneManager.ensureZoneExists()
        try await zoneManager.ensureSubscriptionExists()

        // 推送本機待處理變更
        try await pushPendingChanges()

        // 拉取雲端變更
        try await fetchChanges()
    }

    // MARK: - Push

    /// 推送所有待處理的本機變更到 CloudKit。
    func pushPendingChanges() async throws {
        let pending = changeTracker.getPendingChanges()
        guard !pending.isEmpty else { return }

        let container = DIContainer.shared
        var recordsToSave: [CKRecord] = []

        for change in pending {
            if let record = try await buildRecord(for: change, container: container) {
                recordsToSave.append(record)
            }
        }

        guard !recordsToSave.isEmpty else {
            changeTracker.removeChanges(pending)
            return
        }

        // 分批推送（CloudKit 限制每次最多 400 筆）
        let batchSize = 400
        for batch in stride(from: 0, to: recordsToSave.count, by: batchSize) {
            let end = min(batch + batchSize, recordsToSave.count)
            let batchRecords = Array(recordsToSave[batch..<end])

            try await modifyRecords(save: batchRecords, delete: [])
        }

        changeTracker.removeChanges(pending)
    }

    /// Debounced 推送：DB 變更後延遲 3 秒批次推送。
    func schedulePush() {
        pushDebounceTask?.cancel()
        pushDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            try? await pushPendingChanges()
        }
    }

    // MARK: - Fetch

    /// 使用 server change token 增量拉取雲端變更。
    func fetchChanges() async throws {
        let db = try requireDatabase()
        let zoneID = zoneManager.zoneID
        let token = loadServerChangeToken()

        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []
        var newToken: CKServerChangeToken?

        let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        options.previousServerChangeToken = token

        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [zoneID: options]
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result {
                    changedRecords.append(record)
                }
            }

            operation.recordWithIDWasDeletedBlock = { recordID, _ in
                deletedRecordIDs.append(recordID)
            }

            operation.recordZoneChangeTokensUpdatedBlock = { _, serverToken, _ in
                newToken = serverToken
            }

            operation.recordZoneFetchResultBlock = { _, result in
                switch result {
                case .success(let (serverToken, _, _)):
                    newToken = serverToken
                case .failure:
                    break
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            db.add(operation)
        }

        // 處理拉取到的變更
        for record in changedRecords {
            await applyRemoteChange(record)
        }

        // 儲存新的 change token
        if let newToken {
            saveServerChangeToken(newToken)
        }
    }

    // MARK: - Reset

    /// 刪除雲端 Zone 中的所有資料。
    func resetCloudData() async throws {
        try await zoneManager.deleteZone()
        changeTracker.clearAll()
        saveServerChangeToken(nil)
    }

    // MARK: - Build Records

    private func buildRecord(
        for change: CloudKitChangeTracker.PendingChange,
        container: DIContainer
    ) async throws -> CKRecord? {
        switch change.type {
        case .manga:
            guard let manga = try await container.mangaRepository.getManga(id: change.localId) else { return nil }
            return CloudKitRecordMapper.record(from: manga)

        case .chapter:
            guard let chapter = try await container.chapterRepository.getChapter(id: change.localId) else { return nil }
            guard let manga = try await container.mangaRepository.getManga(id: chapter.mangaId) else { return nil }
            return CloudKitRecordMapper.record(from: chapter, mangaSource: manga.source, mangaUrl: manga.url)

        case .category:
            let categories = try await container.categoryRepository.getAll()
            guard let category = categories.first(where: { $0.id == change.localId }) else { return nil }
            return CloudKitRecordMapper.record(from: category)

        case .track:
            // Track 的 localId 是 track.id，需要找到對應的 manga
            let allFavorites = try await container.mangaRepository.getFavorites()
            for manga in allFavorites {
                let tracks = try await container.trackRepository.getTracksByMangaId(mangaId: manga.id)
                if let track = tracks.first(where: { $0.id == change.localId }) {
                    return CloudKitRecordMapper.record(from: track, mangaSource: manga.source, mangaUrl: manga.url)
                }
            }
            return nil

        case .history:
            // History 變更記錄存的是 chapterId
            guard let chapter = try await container.chapterRepository.getChapter(id: change.localId) else { return nil }
            guard let manga = try await container.mangaRepository.getManga(id: chapter.mangaId) else { return nil }
            // 從 history repository 取得 lastRead 時間
            let histories = try await container.historyRepository.getHistory(query: "")
            let lastRead = histories.first(where: { $0.chapter.id == change.localId })?.lastRead ?? Int64(Date().timeIntervalSince1970 * 1000)
            return CloudKitRecordMapper.historyRecord(
                chapterId: change.localId,
                lastRead: lastRead,
                mangaSource: manga.source,
                mangaUrl: manga.url,
                chapterUrl: chapter.url
            )
        }
    }

    // MARK: - Apply Remote Changes

    private func applyRemoteChange(_ record: CKRecord) async {
        let container = DIContainer.shared

        switch record.recordType {
        case CKRecordType.syncManga:
            await applyMangaChange(record, container: container)
        case CKRecordType.syncChapter:
            await applyChapterChange(record, container: container)
        case CKRecordType.syncCategory:
            await applyCategoryChange(record, container: container)
        case CKRecordType.syncTrack:
            await applyTrackChange(record, container: container)
        case CKRecordType.syncHistory:
            await applyHistoryChange(record, container: container)
        default:
            break
        }
    }

    private func applyMangaChange(_ record: CKRecord, container: DIContainer) async {
        guard let remote = CloudKitRecordMapper.mangaSyncFields(from: record) else { return }

        do {
            if let local = try await container.mangaRepository.getMangaByUrlAndSource(
                url: remote.url, sourceId: remote.source
            ) {
                // 合併衝突
                let localFields = CloudKitRecordMapper.MangaSyncFields(
                    source: local.source, url: local.url, title: local.title,
                    favorite: local.favorite, viewerFlags: local.viewerFlags,
                    chapterFlags: local.chapterFlags, notes: local.notes,
                    lastModifiedAt: local.lastModifiedAt, dateAdded: local.dateAdded
                )
                let merged = CloudKitConflictResolver.resolveManga(local: localFields, remote: remote)

                var update = MangaUpdate()
                update.favorite = merged.favorite
                update.viewerFlags = merged.viewerFlags
                update.chapterFlags = merged.chapterFlags
                update.notes = merged.notes
                try await container.mangaRepository.updatePartial(id: local.id, updates: update)
            } else if remote.favorite {
                // 本機不存在且雲端標記為收藏 → 建立佔位記錄
                let manga = Manga(
                    id: 0, source: remote.source, favorite: true,
                    lastUpdate: 0, nextUpdate: 0, fetchInterval: 0,
                    dateAdded: remote.dateAdded, viewerFlags: remote.viewerFlags,
                    chapterFlags: remote.chapterFlags, coverLastModified: 0,
                    url: remote.url, title: remote.title,
                    artist: nil, author: nil, description: nil,
                    genre: nil, status: 0, thumbnailUrl: nil,
                    updateStrategy: 0, initialized: false,
                    lastModifiedAt: remote.lastModifiedAt,
                    favoriteModifiedAt: nil, version: 0, notes: remote.notes
                )
                try await container.mangaRepository.insert(manga: manga)
            }
        } catch {
            print("[CloudKitSync] 套用漫畫變更失敗：\(error)")
        }
    }

    private func applyChapterChange(_ record: CKRecord, container: DIContainer) async {
        guard let remote = CloudKitRecordMapper.chapterSyncFields(from: record) else { return }

        do {
            // 先找到本機對應的漫畫
            guard let manga = try await container.mangaRepository.getMangaByUrlAndSource(
                url: remote.mangaUrl, sourceId: remote.mangaSource
            ) else { return }

            // 找到本機對應的章節
            guard let localChapter = try await container.chapterRepository.getChapterByUrl(
                url: remote.chapterUrl, mangaId: manga.id
            ) else { return }

            // 合併衝突
            let localFields = CloudKitRecordMapper.ChapterSyncFields(
                mangaSource: remote.mangaSource, mangaUrl: remote.mangaUrl,
                chapterUrl: remote.chapterUrl,
                read: localChapter.read, bookmark: localChapter.bookmark,
                lastPageRead: localChapter.lastPageRead,
                lastModifiedAt: localChapter.lastModifiedAt
            )
            let merged = CloudKitConflictResolver.resolveChapter(local: localFields, remote: remote)

            try await container.chapterRepository.updatePartial(
                id: localChapter.id,
                read: merged.read,
                bookmark: merged.bookmark,
                lastPageRead: merged.lastPageRead
            )
        } catch {
            print("[CloudKitSync] 套用章節變更失敗：\(error)")
        }
    }

    private func applyCategoryChange(_ record: CKRecord, container: DIContainer) async {
        guard let remote = CloudKitRecordMapper.categorySyncFields(from: record) else { return }

        do {
            let allCategories = try await container.categoryRepository.getAll()
            if let existing = allCategories.first(where: { $0.name == remote.name }) {
                var updated = existing
                updated = ShinsouDomain.Category(id: existing.id, name: remote.name, sort: remote.sort, flags: remote.flags)
                try await container.categoryRepository.update(category: updated)
            } else {
                let newCategory = ShinsouDomain.Category(id: 0, name: remote.name, sort: remote.sort, flags: remote.flags)
                try await container.categoryRepository.insert(category: newCategory)
            }
        } catch {
            print("[CloudKitSync] 套用分類變更失敗：\(error)")
        }
    }

    private func applyTrackChange(_ record: CKRecord, container: DIContainer) async {
        guard let remote = CloudKitRecordMapper.trackSyncFields(from: record) else { return }

        do {
            guard let manga = try await container.mangaRepository.getMangaByUrlAndSource(
                url: remote.mangaUrl, sourceId: remote.mangaSource
            ) else { return }

            let tracks = try await container.trackRepository.getTracksByMangaId(mangaId: manga.id)

            if let localTrack = tracks.first(where: { $0.trackerId == remote.trackerId }) {
                let localFields = CloudKitRecordMapper.TrackSyncFields(
                    mangaSource: remote.mangaSource, mangaUrl: remote.mangaUrl,
                    trackerId: localTrack.trackerId, remoteId: localTrack.remoteId,
                    title: localTrack.title, lastChapterRead: localTrack.lastChapterRead,
                    totalChapters: localTrack.totalChapters, status: localTrack.status,
                    score: localTrack.score, remoteUrl: localTrack.remoteUrl,
                    startDate: localTrack.startDate, finishDate: localTrack.finishDate
                )
                let merged = CloudKitConflictResolver.resolveTrack(local: localFields, remote: remote)

                let updatedTrack = Track(
                    id: localTrack.id, mangaId: manga.id,
                    trackerId: merged.trackerId, remoteId: merged.remoteId,
                    title: merged.title, lastChapterRead: merged.lastChapterRead,
                    totalChapters: merged.totalChapters, status: merged.status,
                    score: merged.score, remoteUrl: merged.remoteUrl,
                    startDate: merged.startDate, finishDate: merged.finishDate
                )
                try await container.trackRepository.update(track: updatedTrack)
            } else {
                let newTrack = Track(
                    id: 0, mangaId: manga.id,
                    trackerId: remote.trackerId, remoteId: remote.remoteId,
                    title: remote.title, lastChapterRead: remote.lastChapterRead,
                    totalChapters: remote.totalChapters, status: remote.status,
                    score: remote.score, remoteUrl: remote.remoteUrl,
                    startDate: remote.startDate, finishDate: remote.finishDate
                )
                try await container.trackRepository.insert(track: newTrack)
            }
        } catch {
            print("[CloudKitSync] 套用追蹤變更失敗：\(error)")
        }
    }

    private func applyHistoryChange(_ record: CKRecord, container: DIContainer) async {
        guard let remote = CloudKitRecordMapper.historySyncFields(from: record) else { return }

        do {
            guard let manga = try await container.mangaRepository.getMangaByUrlAndSource(
                url: remote.mangaUrl, sourceId: remote.mangaSource
            ) else { return }

            guard let chapter = try await container.chapterRepository.getChapterByUrl(
                url: remote.chapterUrl, mangaId: manga.id
            ) else { return }

            try await container.historyRepository.upsert(
                chapterId: chapter.id,
                readAt: remote.lastRead
            )
        } catch {
            print("[CloudKitSync] 套用歷史變更失敗：\(error)")
        }
    }

    // MARK: - CKModifyRecordsOperation

    private func modifyRecords(save: [CKRecord], delete: [CKRecord.ID]) async throws {
        let operation = CKModifyRecordsOperation(recordsToSave: save, recordIDsToDelete: delete)
        operation.savePolicy = .changedKeys

        let db = try requireDatabase()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            db.add(operation)
        }
    }

    // MARK: - Server Change Token

    private func loadServerChangeToken() -> CKServerChangeToken? {
        guard let data = UserDefaults.standard.data(forKey: SettingsKeys.cloudKitServerChangeToken) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func saveServerChangeToken(_ token: CKServerChangeToken?) {
        if let token, let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: SettingsKeys.cloudKitServerChangeToken)
        } else {
            UserDefaults.standard.removeObject(forKey: SettingsKeys.cloudKitServerChangeToken)
        }
    }
}
