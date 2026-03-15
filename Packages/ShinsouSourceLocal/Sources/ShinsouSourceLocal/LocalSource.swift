import Foundation
import ShinsouSourceAPI
import ShinsouCore

/// Local manga source that reads from the device's file system.
/// Supports: folders, ZIP, CBZ, RAR, CBR, 7Z, CB7, EPUB
public final class LocalSource: Source, @unchecked Sendable {
    public static let sourceId: Int64 = 0

    public var id: Int64 { Self.sourceId }
    public var name: String { "Local source" }
    public var lang: String { "other" }

    private let baseDirectory: URL

    public init(baseDirectory: URL? = nil) {
        self.baseDirectory = baseDirectory ?? DiskUtil.documentsDirectory.appendingPathComponent("local", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.baseDirectory, withIntermediateDirectories: true)
    }

    public func getMangaDetails(manga: SManga) async throws -> SManga {
        var updated = manga
        let mangaDir = baseDirectory.appendingPathComponent(manga.url)

        // Try to parse ComicInfo.xml for metadata
        let comicInfoUrl = mangaDir.appendingPathComponent("ComicInfo.xml")
        if FileManager.default.fileExists(atPath: comicInfoUrl.path),
           let data = try? Data(contentsOf: comicInfoUrl),
           let info = ComicInfo.parse(from: data) {
            updated.title = info.title ?? manga.title
            updated.author = info.writer
            updated.artist = info.penciller
            updated.description = info.summary
            if let genres = info.genre {
                updated.genre = genres.components(separatedBy: ",").map { $0.trimmed }
            }
        }
        updated.initialized = true
        return updated
    }

    public func getChapterList(manga: SManga) async throws -> [SChapter] {
        let mangaDir = baseDirectory.appendingPathComponent(manga.url)
        let contents = try FileManager.default.contentsOfDirectory(
            at: mangaDir, includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        )

        let supportedExtensions = Set(["zip", "cbz", "rar", "cbr", "7z", "cb7", "epub"])
        var chapters: [SChapter] = []

        for item in contents {
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let ext = item.pathExtension.lowercased()

            if isDirectory || supportedExtensions.contains(ext) {
                let name = item.deletingPathExtension().lastPathComponent
                chapters.append(SChapter(
                    url: "\(manga.url)/\(item.lastPathComponent)",
                    name: name,
                    chapterNumber: name.chapterNumber()
                ))
            }
        }

        return chapters.sorted { $0.chapterNumber > $1.chapterNumber }
    }

    public func getPageList(chapter: SChapter) async throws -> [Page] {
        let chapterPath = baseDirectory.appendingPathComponent(chapter.url)
        let isDirectory = (try? chapterPath.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false

        if isDirectory {
            return try loadPagesFromDirectory(chapterPath)
        } else {
            // Archive file - will be handled by ArchivePageLoader
            return [Page(index: 0, url: chapter.url)]
        }
    }

    private func loadPagesFromDirectory(_ directory: URL) throws -> [Page] {
        let imageExtensions = Set(["jpg", "jpeg", "png", "gif", "webp", "avif", "heic"])
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        return contents
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .enumerated()
            .map { Page(index: $0.offset, url: "", imageUrl: $0.element.absoluteString) }
    }
}
