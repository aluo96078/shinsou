import Foundation

public struct LibraryManga: Identifiable, Sendable {
    public var id: Int64 { manga.id }
    public let manga: Manga
    public let totalChapters: Int
    public let readCount: Int
    public let bookmarkCount: Int
    public let latestUpload: Int64
    public let chapterFetchedAt: Int64
    public let lastRead: Int64
    public let category: Int64

    public var unreadCount: Int { totalChapters - readCount }

    public var hasStarted: Bool { readCount > 0 }

    public var hasBookmarks: Bool { bookmarkCount > 0 }

    public init(
        manga: Manga,
        totalChapters: Int = 0,
        readCount: Int = 0,
        bookmarkCount: Int = 0,
        latestUpload: Int64 = 0,
        chapterFetchedAt: Int64 = 0,
        lastRead: Int64 = 0,
        category: Int64 = 0
    ) {
        self.manga = manga
        self.totalChapters = totalChapters
        self.readCount = readCount
        self.bookmarkCount = bookmarkCount
        self.latestUpload = latestUpload
        self.chapterFetchedAt = chapterFetchedAt
        self.lastRead = lastRead
        self.category = category
    }
}
