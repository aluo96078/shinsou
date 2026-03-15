import Foundation

/// A basic interface for creating a manga source.
/// It could be an online source, a local source, etc.
public protocol Source: Sendable {
    /// Unique identifier for this source.
    var id: Int64 { get }

    /// Name of this source.
    var name: String { get }

    /// ISO 639-1 language code.
    var lang: String { get }

    /// Get the updated details for a manga.
    func getMangaDetails(manga: SManga) async throws -> SManga

    /// Get all the available chapters for a manga.
    func getChapterList(manga: SManga) async throws -> [SChapter]

    /// Get the list of pages a chapter has.
    func getPageList(chapter: SChapter) async throws -> [Page]
}

public extension Source {
    var lang: String { "" }
}
