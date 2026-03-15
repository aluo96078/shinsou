import Foundation
import ShinsouDomain

/// Observes all extension repositories reactively.
struct GetExtensionRepos {

    private let repository: any ExtensionRepoRepository

    init(repository: any ExtensionRepoRepository) {
        self.repository = repository
    }

    func subscribe() -> AsyncStream<[ExtensionRepo]> {
        repository.observeAll()
    }

    func execute() async throws -> [ExtensionRepo] {
        try await repository.getAll()
    }
}
