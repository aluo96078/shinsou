import Foundation
import Compression
import ShinsouDomain
import ShinsouData

// MARK: - Errors

enum BackupCreatorError: LocalizedError {
    case encodingFailed(Error)
    case compressionFailed
    case fileWriteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .encodingFailed(let e):   return "備份編碼失敗：\(e.localizedDescription)"
        case .compressionFailed:       return "備份壓縮失敗"
        case .fileWriteFailed(let e):  return "備份檔案寫入失敗：\(e.localizedDescription)"
        }
    }
}

// MARK: - BackupCreator

/// 負責將目前書庫狀態序列化為 `.shinsoubackup` 壓縮備份檔案。
/// 標記為 @MainActor 以便存取 MainActor 隔離的 repository 屬性。
@MainActor
final class BackupCreator {

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

    /// 建立備份並寫入暫存目錄，回傳備份檔案 URL。
    /// - Returns: `.shinsoubackup` 檔案的 URL
    func createBackup() async throws -> URL {
        // 1. 取得所有加入書庫的漫畫
        let favorites = try await mangaRepository.getFavorites()

        // 2. 取得所有分類
        let allCategories = try await categoryRepository.getAll()
        let userCategories = allCategories.filter { !$0.isSystemCategory }
        let backupCategories = userCategories.map { BackupCategory(category: $0) }

        // 3. 建立 sort -> id 反向對應（用於查詢漫畫所屬分類）
        let sortToId: [Int: Int64] = Dictionary(
            uniqueKeysWithValues: userCategories.map { ($0.sort, $0.id) }
        )

        // 4. 對每本漫畫收集章節、追蹤、歷史
        var backupMangas: [BackupManga] = []
        for manga in favorites {
            let backupManga = try await buildBackupManga(
                manga: manga,
                userCategories: userCategories,
                sortToId: sortToId
            )
            backupMangas.append(backupManga)
        }

        // 5. 組裝根備份物件
        let backup = ShinsouBackup(
            version: ShinsouBackup.currentVersion,
            createdAt: Int64(Date().timeIntervalSince1970 * 1000),
            mangas: backupMangas,
            categories: backupCategories
        )

        // 6. 編碼為 JSON（排序鍵以確保可重現的輸出）
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let jsonData: Data
        do {
            jsonData = try encoder.encode(backup)
        } catch {
            throw BackupCreatorError.encodingFailed(error)
        }

        // 7. 以 zlib 壓縮
        guard let compressedData = compress(data: jsonData) else {
            throw BackupCreatorError.compressionFailed
        }

        // 8. 寫入暫存檔案
        let fileURL = buildBackupFileURL()
        do {
            try compressedData.write(to: fileURL, options: .atomic)
        } catch {
            throw BackupCreatorError.fileWriteFailed(error)
        }

        return fileURL
    }

    // MARK: - Private Helpers

    private func buildBackupManga(
        manga: Manga,
        userCategories: [ShinsouDomain.Category],
        sortToId: [Int: Int64]
    ) async throws -> BackupManga {

        // 章節
        let domainChapters = try await chapterRepository.getChaptersByMangaId(mangaId: manga.id)
        let backupChapters = domainChapters.map { BackupChapter(chapter: $0) }

        // 追蹤
        let domainTracks = try await trackRepository.getTracksByMangaId(mangaId: manga.id)
        let backupTracks = domainTracks.map { BackupTrack(track: $0) }

        // 此漫畫所屬分類（以 sort index 表示）
        let mangaCategories = try await categoryRepository.getCategoriesForManga(mangaId: manga.id)
        let categorySorts = mangaCategories
            .filter { !$0.isSystemCategory }
            .map { $0.sort }
            .sorted()

        // 歷史：從各章節的 URL 對應
        let chapterUrlSet = Set(domainChapters.map { $0.url })
        let historyItems = try await fetchHistory(for: manga, chapterUrls: chapterUrlSet)

        return BackupManga(
            manga: manga,
            chapters: backupChapters,
            categories: categorySorts,
            tracks: backupTracks,
            history: historyItems
        )
    }

    /// 透過 HistoryRepository 查詢空字串（取得全部），再篩選屬於此漫畫的章節
    private func fetchHistory(for manga: Manga, chapterUrls: Set<String>) async throws -> [BackupHistory] {
        // HistoryRepository 目前僅提供依 query 搜尋的介面；
        // 傳入空字串可取得所有歷史，再以章節 URL 篩選
        let allHistory = try await historyRepository.getHistory(query: "")
        return allHistory
            .filter { $0.manga.id == manga.id && chapterUrls.contains($0.chapter.url) }
            .map { item in
                BackupHistory(
                    chapterUrl: item.chapter.url,
                    lastRead: item.lastRead,
                    timeRead: 0  // HistoryItem 目前不提供 timeRead，保留為 0
                )
            }
    }

    /// 使用 Foundation Compression（zlib）壓縮資料
    private func compress(data: Data) -> Data? {
        let sourceSize = data.count
        // 最大輸出緩衝區：略大於輸入（未壓縮極端情況）
        let destinationBufferSize = sourceSize + 1024
        var destinationBuffer = [UInt8](repeating: 0, count: destinationBufferSize)

        let compressedSize = data.withUnsafeBytes { sourcePointer -> Int in
            guard let baseAddress = sourcePointer.baseAddress else { return 0 }
            return compression_encode_buffer(
                &destinationBuffer,
                destinationBufferSize,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                sourceSize,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard compressedSize > 0 else { return nil }
        return Data(destinationBuffer.prefix(compressedSize))
    }

    /// 組裝備份檔案的目標路徑（Documents/Backups/shinsou_YYYYMMDD_HHmmss.shinsoubackup）
    private func buildBackupFileURL() -> URL {
        let backupDir = AutoBackupManager.shared.backupDirectory
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let filename = "shinsou_\(timestamp).shinsoubackup"
        return backupDir.appendingPathComponent(filename)
    }
}
