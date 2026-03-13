import Foundation

public protocol UpdatesRepository: Sendable {
    func getRecentUpdates(limit: Int) async throws -> [UpdateItem]
    func observeRecentUpdates(limit: Int) -> AsyncStream<[UpdateItem]>
}
