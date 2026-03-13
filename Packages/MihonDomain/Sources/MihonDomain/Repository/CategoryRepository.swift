import Foundation

public protocol CategoryRepository: Sendable {
    func getAll() async throws -> [Category]
    func observeAll() -> AsyncStream<[Category]>
    func getCategoriesForManga(mangaId: Int64) async throws -> [Category]
    func insert(category: Category) async throws -> Int64
    func update(category: Category) async throws
    func delete(categoryId: Int64) async throws
    func setMangaCategories(mangaId: Int64, categoryIds: [Int64]) async throws
}
