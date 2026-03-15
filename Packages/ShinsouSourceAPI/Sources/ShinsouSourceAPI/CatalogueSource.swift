import Foundation

/// A source that supports browsing and searching for manga.
public protocol CatalogueSource: Source {
    /// Whether the source has support for latest updates.
    var supportsLatest: Bool { get }

    /// Get a page with a list of popular manga.
    func getPopularManga(page: Int) async throws -> MangasPage

    /// Search for manga with query and filters.
    func getSearchManga(page: Int, query: String, filters: FilterList) async throws -> MangasPage

    /// Get a page with a list of latest manga updates.
    func getLatestUpdates(page: Int) async throws -> MangasPage

    /// Returns the list of filters for the source.
    func getFilterList() -> FilterList
}
