import Foundation

public protocol ExtensionRepoRepository: Sendable {
    func getAll() async throws -> [ExtensionRepo]
    func observeAll() -> AsyncStream<[ExtensionRepo]>
    func getRepo(baseUrl: String) async throws -> ExtensionRepo?
    func insert(repo: ExtensionRepo) async throws
    func update(repo: ExtensionRepo) async throws
    func delete(baseUrl: String) async throws
    func getCount() async throws -> Int
}
