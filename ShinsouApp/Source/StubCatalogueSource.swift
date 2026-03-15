import Foundation
import ShinsouSourceAPI

/// Source created from extension metadata that uses HTML scraping to fetch manga.
/// Replaces the old stub that returned empty results — now actually fetches content
/// from the extension's baseUrl using auto-detected theme selectors.
final class StubCatalogueSource: CatalogueSource, @unchecked Sendable {
    let id: Int64
    let name: String
    let lang: String
    let supportsLatest: Bool = true

    /// The base URL from the extension index metadata.
    let baseUrl: String?

    /// Lazy-initialized scraper — created on first use.
    private var _scraper: ParsedHttpSource?
    private var scraper: ParsedHttpSource? {
        if let s = _scraper { return s }
        guard let base = baseUrl, !base.isEmpty else { return nil }
        let s = ParsedHttpSource(baseUrl: base)
        _scraper = s
        return s
    }

    init(entry: SourceIndexEntry) {
        self.id = entry.id
        self.name = entry.name
        self.lang = entry.lang
        self.baseUrl = entry.baseUrl
    }

    // MARK: - CatalogueSource

    func getPopularManga(page: Int) async throws -> MangasPage {
        guard let scraper else {
            throw SourceError.noBaseUrl(name)
        }
        return try await scraper.getPopularManga(page: page)
    }

    func getSearchManga(page: Int, query: String, filters: FilterList) async throws -> MangasPage {
        guard let scraper else {
            throw SourceError.noBaseUrl(name)
        }
        return try await scraper.getSearchManga(page: page, query: query, filters: filters)
    }

    func getLatestUpdates(page: Int) async throws -> MangasPage {
        guard let scraper else {
            throw SourceError.noBaseUrl(name)
        }
        return try await scraper.getLatestUpdates(page: page)
    }

    func getFilterList() -> FilterList {
        scraper?.getFilterList() ?? []
    }

    // MARK: - Source

    func getMangaDetails(manga: SManga) async throws -> SManga {
        guard let scraper else { return manga }
        return try await scraper.getMangaDetails(manga: manga)
    }

    func getChapterList(manga: SManga) async throws -> [SChapter] {
        guard let scraper else { return [] }
        return try await scraper.getChapterList(manga: manga)
    }

    func getPageList(chapter: SChapter) async throws -> [Page] {
        guard let scraper else { return [] }
        return try await scraper.getPageList(chapter: chapter)
    }
}

// MARK: - Errors

enum SourceError: Error, LocalizedError {
    case noBaseUrl(String)

    var errorDescription: String? {
        switch self {
        case .noBaseUrl(let name):
            return "Source '\(name)' has no base URL configured. The extension may not support direct browsing on iOS."
        }
    }
}
