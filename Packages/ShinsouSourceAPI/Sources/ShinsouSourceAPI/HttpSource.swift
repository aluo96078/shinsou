import Foundation
import ShinsouCore

/// Base class for an online HTTP manga source.
/// Subclasses override the parse methods to extract data from web pages.
open class HttpSource: CatalogueSource {
    open var id: Int64 { fatalError("Subclass must override id") }
    open var name: String { fatalError("Subclass must override name") }
    open var lang: String { "" }
    open var baseUrl: String { fatalError("Subclass must override baseUrl") }
    open var supportsLatest: Bool { false }

    public let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - CatalogueSource

    open func getPopularManga(page: Int) async throws -> MangasPage {
        let request = try popularMangaRequest(page: page)
        let (data, _) = try await session.data(for: request)
        return try popularMangaParse(data: data)
    }

    open func getSearchManga(page: Int, query: String, filters: FilterList) async throws -> MangasPage {
        let request = try searchMangaRequest(page: page, query: query, filters: filters)
        let (data, _) = try await session.data(for: request)
        return try searchMangaParse(data: data)
    }

    open func getLatestUpdates(page: Int) async throws -> MangasPage {
        let request = try latestUpdatesRequest(page: page)
        let (data, _) = try await session.data(for: request)
        return try latestUpdatesParse(data: data)
    }

    open func getMangaDetails(manga: SManga) async throws -> SManga {
        let request = try mangaDetailsRequest(manga: manga)
        let (data, _) = try await session.data(for: request)
        return try mangaDetailsParse(data: data)
    }

    open func getChapterList(manga: SManga) async throws -> [SChapter] {
        let request = try chapterListRequest(manga: manga)
        let (data, _) = try await session.data(for: request)
        return try chapterListParse(data: data)
    }

    open func getPageList(chapter: SChapter) async throws -> [Page] {
        let request = try pageListRequest(chapter: chapter)
        let (data, _) = try await session.data(for: request)
        return try pageListParse(data: data)
    }

    open func getFilterList() -> FilterList { [] }

    // MARK: - Request builders (override in subclass)

    open func popularMangaRequest(page: Int) throws -> URLRequest {
        fatalError("Subclass must override popularMangaRequest")
    }

    open func searchMangaRequest(page: Int, query: String, filters: FilterList) throws -> URLRequest {
        fatalError("Subclass must override searchMangaRequest")
    }

    open func latestUpdatesRequest(page: Int) throws -> URLRequest {
        fatalError("Subclass must override latestUpdatesRequest")
    }

    open func mangaDetailsRequest(manga: SManga) throws -> URLRequest {
        URLRequest(url: URL(string: baseUrl + manga.url)!)
    }

    open func chapterListRequest(manga: SManga) throws -> URLRequest {
        URLRequest(url: URL(string: baseUrl + manga.url)!)
    }

    open func pageListRequest(chapter: SChapter) throws -> URLRequest {
        URLRequest(url: URL(string: baseUrl + chapter.url)!)
    }

    // MARK: - Response parsers (override in subclass)

    open func popularMangaParse(data: Data) throws -> MangasPage {
        fatalError("Subclass must override popularMangaParse")
    }

    open func searchMangaParse(data: Data) throws -> MangasPage {
        fatalError("Subclass must override searchMangaParse")
    }

    open func latestUpdatesParse(data: Data) throws -> MangasPage {
        fatalError("Subclass must override latestUpdatesParse")
    }

    open func mangaDetailsParse(data: Data) throws -> SManga {
        fatalError("Subclass must override mangaDetailsParse")
    }

    open func chapterListParse(data: Data) throws -> [SChapter] {
        fatalError("Subclass must override chapterListParse")
    }

    open func pageListParse(data: Data) throws -> [Page] {
        fatalError("Subclass must override pageListParse")
    }
}
