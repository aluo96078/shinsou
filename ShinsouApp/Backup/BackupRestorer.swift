import Foundation
import Compression
import ShinsouDomain
import ShinsouData

// MARK: - BackupRestoreOptions

/// 控制哪些資料類別要被還原的選項結構。
struct BackupRestoreOptions: Equatable {
    var restoreManga: Bool      = true
    var restoreCategories: Bool = true
    var restoreChapters: Bool   = true
    var restoreTracks: Bool     = true
    var restoreHistory: Bool    = true

    static let all = BackupRestoreOptions()
    static let none = BackupRestoreOptions(
        restoreManga: false,
        restoreCategories: false,
        restoreChapters: false,
        restoreTracks: false,
        restoreHistory: false
    )
}

// MARK: - BackupPreview

/// 備份內容的預覽摘要，用於在還原前向使用者顯示。
struct BackupPreview {
    let mangaCount: Int
    let categoryCount: Int
    let chapterCount: Int
    let trackCount: Int
    let historyCount: Int
    let createdAt: Date
    let version: Int

    var formattedCreatedAt: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "zh-TW")
        return f.string(from: createdAt)
    }
}

// MARK: - Result

/// 還原操作的結果摘要
struct BackupRestoreResult {
    let mangaCount: Int
    let chapterCount: Int
    let categoryCount: Int
    let trackCount: Int
    /// 非致命性錯誤（單本漫畫或單個章節還原失敗時記錄，不中斷整體流程）
    let errors: [String]
}

// MARK: - Errors

enum BackupRestorerError: LocalizedError {
    case fileReadFailed(Error)
    case decompressionFailed
    case decodingFailed(Error)
    case versionUnsupported(Int)

    var errorDescription: String? {
        switch self {
        case .fileReadFailed(let e):     return "讀取備份檔案失敗：\(e.localizedDescription)"
        case .decompressionFailed:       return "備份解壓縮失敗"
        case .decodingFailed(let e):     return "備份解碼失敗：\(e.localizedDescription)"
        case .versionUnsupported(let v): return "不支援的備份版本：\(v)"
        }
    }
}

// MARK: - BackupRestorer

/// 從 `.shinsoubackup` 檔案還原書庫資料。
/// 標記為 @MainActor 以便存取 MainActor 隔離的 repository 屬性。
@MainActor
final class BackupRestorer {

    // MARK: - Dependencies

    private let mangaRepository: MangaRepository
    private let chapterRepository: ChapterRepository
    private let categoryRepository: CategoryRepository
    private let trackRepository: TrackRepository
    private let historyRepository: HistoryRepository

    // MARK: - Init

    init() {
        let di = DIContainer.shared
        self.mangaRepository = di.mangaRepository
        self.chapterRepository = di.chapterRepository
        self.categoryRepository = di.categoryRepository
        self.trackRepository = di.trackRepository
        self.historyRepository = di.historyRepository
    }

    /// 用於測試時注入 mock 依賴
    init(
        mangaRepository: MangaRepository,
        chapterRepository: ChapterRepository,
        categoryRepository: CategoryRepository,
        trackRepository: TrackRepository,
        historyRepository: HistoryRepository
    ) {
        self.mangaRepository = mangaRepository
        self.chapterRepository = chapterRepository
        self.categoryRepository = categoryRepository
        self.trackRepository = trackRepository
        self.historyRepository = historyRepository
    }

    // MARK: - Public API

    /// 解析備份檔案並回傳預覽摘要，不執行任何寫入操作。
    /// - Parameter url: `.shinsoubackup` 檔案路徑
    func previewBackup(from url: URL) async throws -> BackupPreview {
        let backup = try loadBackup(from: url)

        let chapterCount = backup.mangas.reduce(0) { $0 + $1.chapters.count }
        let trackCount   = backup.mangas.reduce(0) { $0 + $1.tracks.count }
        let historyCount = backup.mangas.reduce(0) { $0 + $1.history.count }

        return BackupPreview(
            mangaCount: backup.mangas.count,
            categoryCount: backup.categories.count,
            chapterCount: chapterCount,
            trackCount: trackCount,
            historyCount: historyCount,
            createdAt: Date(timeIntervalSince1970: Double(backup.createdAt) / 1000.0),
            version: backup.version
        )
    }

    /// 從指定 URL 還原備份（完整還原，向後相容舊呼叫點）。
    /// - Parameter url: `.shinsoubackup` 檔案的路徑（支援本機與 Files 共享）
    /// - Returns: 還原結果摘要
    func restoreBackup(from url: URL) async throws -> BackupRestoreResult {
        try await restoreBackup(from: url, options: .all)
    }

    /// 從指定 URL 依照 options 選擇性還原備份。
    /// - Parameters:
    ///   - url: `.shinsoubackup` 檔案的路徑（支援本機與 Files 共享）
    ///   - options: 控制哪些資料類別要還原的選項
    /// - Returns: 還原結果摘要
    func restoreBackup(from url: URL, options: BackupRestoreOptions) async throws -> BackupRestoreResult {
        let backup = try loadBackup(from: url)

        // 1. 還原分類，取得 sort -> DB id 的對應表
        var categoryIdMap: [Int: Int64] = [:]
        var categoryCount = 0
        if options.restoreCategories {
            categoryIdMap = try await restoreCategories(backup.categories)
            categoryCount = categoryIdMap.count
        }

        // 2. 若不還原漫畫主體，直接回傳
        guard options.restoreManga else {
            return BackupRestoreResult(
                mangaCount: 0,
                chapterCount: 0,
                categoryCount: categoryCount,
                trackCount: 0,
                errors: []
            )
        }

        // 3. 逐一還原漫畫
        var mangaCount = 0
        var chapterCount = 0
        var trackCount = 0
        var errors: [String] = []

        for backupManga in backup.mangas {
            do {
                let result = try await restoreManga(
                    backupManga,
                    categoryIdMap: categoryIdMap,
                    options: options
                )
                mangaCount += 1
                chapterCount += result.chapters
                trackCount += result.tracks
            } catch {
                errors.append("漫畫「\(backupManga.title)」還原失敗：\(error.localizedDescription)")
            }
        }

        return BackupRestoreResult(
            mangaCount: mangaCount,
            chapterCount: chapterCount,
            categoryCount: categoryCount,
            trackCount: trackCount,
            errors: errors
        )
    }

    // MARK: - File Loading

    /// 讀取、解壓縮並解碼備份檔案。
    private func loadBackup(from url: URL) throws -> ShinsouBackup {
        // 讀取檔案資料
        let rawData: Data
        do {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            rawData = try Data(contentsOf: url)
        } catch {
            throw BackupRestorerError.fileReadFailed(error)
        }

        // 解壓縮
        guard let jsonData = decompress(data: rawData) else {
            throw BackupRestorerError.decompressionFailed
        }

        // 解碼 JSON
        let backup: ShinsouBackup
        do {
            backup = try JSONDecoder().decode(ShinsouBackup.self, from: jsonData)
        } catch {
            throw BackupRestorerError.decodingFailed(error)
        }

        // 版本檢查
        guard backup.version <= ShinsouBackup.currentVersion else {
            throw BackupRestorerError.versionUnsupported(backup.version)
        }

        return backup
    }

    // MARK: - Category Restore

    /// 還原分類，回傳 sort index -> DB id 對應表。
    /// 已存在同名分類時直接使用現有 id，避免重複建立。
    private func restoreCategories(_ backupCategories: [BackupCategory]) async throws -> [Int: Int64] {
        let existing = try await categoryRepository.getAll()
        let existingByName: [String: ShinsouDomain.Category] = Dictionary(
            uniqueKeysWithValues: existing.map { ($0.name, $0) }
        )

        var sortToId: [Int: Int64] = [:]
        for bc in backupCategories {
            if let existing = existingByName[bc.name] {
                sortToId[bc.sort] = existing.id
            } else {
                let newCategory = bc.toDomainCategory()
                let newId = try await categoryRepository.insert(category: newCategory)
                sortToId[bc.sort] = newId
            }
        }
        return sortToId
    }

    // MARK: - Manga Restore

    private struct MangaRestoreResult {
        let chapters: Int
        let tracks: Int
    }

    /// 還原單本漫畫（插入或更新）及其所有關聯資料。
    private func restoreManga(
        _ bm: BackupManga,
        categoryIdMap: [Int: Int64],
        options: BackupRestoreOptions
    ) async throws -> MangaRestoreResult {

        // 查詢此漫畫是否已在書庫中
        let existingManga = try await mangaRepository.getMangaByUrlAndSource(
            url: bm.url,
            sourceId: bm.source
        )

        let mangaId: Int64
        if let existing = existingManga {
            mangaId = existing.id
            try await mangaRepository.updatePartial(
                id: mangaId,
                updates: MangaUpdate(
                    favorite: bm.favorite,
                    chapterFlags: bm.chapterFlags,
                    viewerFlags: bm.viewerFlags,
                    notes: bm.notes ?? ""
                )
            )
        } else {
            let newManga = bm.toDomainManga()
            mangaId = try await mangaRepository.insert(manga: newManga)
        }

        // 還原章節
        var chapterCount = 0
        if options.restoreChapters {
            chapterCount = try await restoreChapters(bm.chapters, mangaId: mangaId)
        }

        // 還原歷史（依賴章節已存在）
        if options.restoreHistory && options.restoreChapters {
            try await restoreHistory(bm.history, bm.chapters, mangaId: mangaId)
        }

        // 還原追蹤
        var trackCount = 0
        if options.restoreTracks {
            trackCount = try await restoreTracks(bm.tracks, mangaId: mangaId)
        }

        // 設定分類關聯
        if options.restoreCategories {
            let resolvedCategoryIds = bm.categories.compactMap { categoryIdMap[$0] }
            if !resolvedCategoryIds.isEmpty {
                try await categoryRepository.setMangaCategories(
                    mangaId: mangaId,
                    categoryIds: resolvedCategoryIds
                )
            }
        }

        return MangaRestoreResult(chapters: chapterCount, tracks: trackCount)
    }

    // MARK: - Chapter Restore

    private func restoreChapters(_ backupChapters: [BackupChapter], mangaId: Int64) async throws -> Int {
        var restoredCount = 0
        for bc in backupChapters {
            let existing = try await chapterRepository.getChapterByUrl(url: bc.url, mangaId: mangaId)
            if let existing = existing {
                try await chapterRepository.updatePartial(
                    id: existing.id,
                    read: bc.read,
                    bookmark: bc.bookmark,
                    lastPageRead: bc.lastPageRead
                )
            } else {
                let newChapter = bc.toDomainChapter(mangaId: mangaId)
                _ = try await chapterRepository.insert(chapter: newChapter)
            }
            restoredCount += 1
        }
        return restoredCount
    }

    // MARK: - History Restore

    private func restoreHistory(
        _ histories: [BackupHistory],
        _ backupChapters: [BackupChapter],
        mangaId: Int64
    ) async throws {
        var urlToChapterId: [String: Int64] = [:]
        for bc in backupChapters {
            if let ch = try await chapterRepository.getChapterByUrl(url: bc.url, mangaId: mangaId) {
                urlToChapterId[bc.url] = ch.id
            }
        }

        for bh in histories {
            guard let chapterId = urlToChapterId[bh.chapterUrl] else { continue }
            try await historyRepository.upsert(chapterId: chapterId, readAt: bh.lastRead)
        }
    }

    // MARK: - Track Restore

    private func restoreTracks(_ backupTracks: [BackupTrack], mangaId: Int64) async throws -> Int {
        let existingTracks = try await trackRepository.getTracksByMangaId(mangaId: mangaId)
        let existingByTracker: [Int: Track] = Dictionary(
            uniqueKeysWithValues: existingTracks.map { ($0.trackerId, $0) }
        )

        var restoredCount = 0
        for bt in backupTracks {
            let newTrack = bt.toDomainTrack(mangaId: mangaId)
            if let existing = existingByTracker[bt.trackerId] {
                let merged = Track(
                    id: existing.id,
                    mangaId: mangaId,
                    trackerId: bt.trackerId,
                    remoteId: bt.remoteId,
                    title: bt.title,
                    lastChapterRead: max(bt.lastChapterRead, existing.lastChapterRead),
                    totalChapters: bt.totalChapters,
                    status: bt.status,
                    score: bt.score,
                    remoteUrl: bt.remoteUrl,
                    startDate: bt.startDate,
                    finishDate: bt.finishDate
                )
                try await trackRepository.update(track: merged)
            } else {
                _ = try await trackRepository.insert(track: newTrack)
            }
            restoredCount += 1
        }
        return restoredCount
    }

    // MARK: - Decompression

    /// 使用 Foundation Compression（zlib）解壓縮資料
    private func decompress(data: Data) -> Data? {
        let sourceSize = data.count
        var destinationBufferSize = sourceSize * 10
        var destinationBuffer = [UInt8](repeating: 0, count: destinationBufferSize)

        let decompressedSize = data.withUnsafeBytes { sourcePointer -> Int in
            guard let baseAddress = sourcePointer.baseAddress else { return 0 }
            return compression_decode_buffer(
                &destinationBuffer,
                destinationBufferSize,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                sourceSize,
                nil,
                COMPRESSION_ZLIB
            )
        }

        if decompressedSize == destinationBufferSize {
            destinationBufferSize = sourceSize * 50
            destinationBuffer = [UInt8](repeating: 0, count: destinationBufferSize)
            let retrySize = data.withUnsafeBytes { sourcePointer -> Int in
                guard let baseAddress = sourcePointer.baseAddress else { return 0 }
                return compression_decode_buffer(
                    &destinationBuffer,
                    destinationBufferSize,
                    baseAddress.assumingMemoryBound(to: UInt8.self),
                    sourceSize,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
            guard retrySize > 0 && retrySize < destinationBufferSize else { return nil }
            return Data(destinationBuffer.prefix(retrySize))
        }

        guard decompressedSize > 0 else { return nil }
        return Data(destinationBuffer.prefix(decompressedSize))
    }
}
