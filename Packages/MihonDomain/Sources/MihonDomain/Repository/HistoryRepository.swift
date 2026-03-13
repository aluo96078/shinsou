import Foundation

public protocol HistoryRepository: Sendable {
    func getHistory(query: String) async throws -> [HistoryItem]
    func observeHistory(query: String) -> AsyncStream<[HistoryItem]>
    func upsert(chapterId: Int64, readAt: Int64) async throws
    func deleteByMangaId(mangaId: Int64) async throws
    func deleteAll() async throws
}

public struct HistoryItem: Identifiable, Sendable {
    public var id: Int64 { chapter.id }
    public let manga: Manga
    public let chapter: Chapter
    public let lastRead: Int64

    public init(manga: Manga, chapter: Chapter, lastRead: Int64) {
        self.manga = manga
        self.chapter = chapter
        self.lastRead = lastRead
    }
}
