import Foundation
import MihonCore

/// Index cache for tracking which chapters are downloaded,
/// avoiding repeated file system lookups.
final class DownloadCache {
    static let shared = DownloadCache()

    private var cache: [Int64: Set<Int64>] = [:] // mangaId -> set of chapterIds
    private var isInitialized = false

    private init() {}

    func initialize() {
        guard !isInitialized else { return }
        let downloadsDir = DiskUtil.downloadsDirectory()

        guard let mangaDirs = try? FileManager.default.contentsOfDirectory(
            at: downloadsDir, includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return }

        for mangaDir in mangaDirs {
            guard let mangaId = Int64(mangaDir.lastPathComponent) else { continue }
            guard let chapterDirs = try? FileManager.default.contentsOfDirectory(
                at: mangaDir, includingPropertiesForKeys: [.isDirectoryKey]
            ) else { continue }

            let chapterIds = Set(chapterDirs.compactMap { Int64($0.lastPathComponent) })
            cache[mangaId] = chapterIds
        }

        isInitialized = true
    }

    func isDownloaded(mangaId: Int64, chapterId: Int64) -> Bool {
        cache[mangaId]?.contains(chapterId) ?? false
    }

    func addDownloaded(mangaId: Int64, chapterId: Int64) {
        cache[mangaId, default: []].insert(chapterId)
    }

    func removeDownloaded(mangaId: Int64, chapterId: Int64) {
        cache[mangaId]?.remove(chapterId)
    }

    func getDownloadCount(mangaId: Int64) -> Int {
        cache[mangaId]?.count ?? 0
    }

    func invalidate() {
        cache.removeAll()
        isInitialized = false
    }
}
