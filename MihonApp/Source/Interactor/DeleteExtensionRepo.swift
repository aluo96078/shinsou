import Foundation
import MihonDomain

/// Deletes an extension repository and its associated data.
struct DeleteExtensionRepo {

    private let repository: any ExtensionRepoRepository

    init(repository: any ExtensionRepoRepository) {
        self.repository = repository
    }

    func execute(baseUrl: String) async throws {
        try await repository.delete(baseUrl: baseUrl)
    }
}
