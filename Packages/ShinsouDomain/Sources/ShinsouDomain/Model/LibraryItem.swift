import Foundation

public struct LibraryItem: Identifiable, Sendable {
    public let libraryManga: LibraryManga
    public let downloadCount: Int64
    public let isLocal: Bool
    public let sourceLanguage: String

    public var id: Int64 { libraryManga.manga.id }

    public var unreadCount: Int64 { Int64(libraryManga.unreadCount) }

    public init(
        libraryManga: LibraryManga,
        downloadCount: Int64 = 0,
        isLocal: Bool = false,
        sourceLanguage: String = ""
    ) {
        self.libraryManga = libraryManga
        self.downloadCount = downloadCount
        self.isLocal = isLocal
        self.sourceLanguage = sourceLanguage
    }

    /// Search matching - supports id:, src: prefixes and general text search
    public func matches(query: String) -> Bool {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return true }

        let manga = libraryManga.manga

        if q.hasPrefix("id:") {
            let idStr = String(q.dropFirst(3))
            return String(manga.id) == idStr
        }

        return manga.title.lowercased().contains(q) ||
            (manga.author?.lowercased().contains(q) ?? false) ||
            (manga.artist?.lowercased().contains(q) ?? false) ||
            (manga.description?.lowercased().contains(q) ?? false) ||
            (manga.genre?.contains(where: { $0.lowercased().contains(q) }) ?? false)
    }
}
