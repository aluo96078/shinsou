import Foundation

public protocol ChapterRepository: Sendable {
    func getChaptersByMangaId(mangaId: Int64) async throws -> [Chapter]
    func getChapter(id: Int64) async throws -> Chapter?
    func getChapterByUrl(url: String, mangaId: Int64) async throws -> Chapter?

    func observeChaptersByMangaId(mangaId: Int64) -> AsyncStream<[Chapter]>

    func insert(chapter: Chapter) async throws -> Int64
    func insertAll(chapters: [Chapter]) async throws
    func update(chapter: Chapter) async throws
    func updatePartial(id: Int64, read: Bool?, bookmark: Bool?, lastPageRead: Int?) async throws
    func delete(chapterIds: [Int64]) async throws
}
