import Foundation
import MihonDomain

/// Creates a new extension repository from a user-supplied URL.
///
/// Supports:
/// - `https://.../index.min.json` — standard Mihon repo (extracts base URL, fetches repo.json)
/// - `https://example.com/repo` — community JS plugin repo (tries repo.json for metadata)
struct CreateExtensionRepo {

    enum Result: Equatable {
        case success
        case invalidUrl
        case repoAlreadyExists
        case duplicateFingerprint(existing: ExtensionRepo, new: ExtensionRepo)
        case error(String)
    }

    private let repository: any ExtensionRepoRepository
    private let service: ExtensionRepoService

    init(
        repository: any ExtensionRepoRepository,
        service: ExtensionRepoService
    ) {
        self.repository = repository
        self.service = service
    }

    func execute(indexUrl: String) async -> Result {
        var trimmed = indexUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // Must be http(s) URL
        guard trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://") else {
            return .invalidUrl
        }

        // If user pasted a full index.min.json URL, extract the base URL
        if trimmed.hasSuffix("/index.min.json") {
            trimmed = String(trimmed.dropLast("/index.min.json".count))
        } else if trimmed.hasSuffix("/index.json") {
            trimmed = String(trimmed.dropLast("/index.json".count))
        }

        let baseUrl = trimmed

        // Try to fetch repo metadata
        let repo: ExtensionRepo
        do {
            repo = try await service.fetchRepoDetails(baseUrl: baseUrl)
        } catch {
            // If repo.json doesn't exist, create a minimal repo entry from the URL
            let name = URL(string: baseUrl)?.lastPathComponent ?? baseUrl
            repo = ExtensionRepo(
                baseUrl: baseUrl,
                name: name,
                shortName: String(name.prefix(3)).uppercased(),
                website: baseUrl,
                signingKeyFingerprint: ""
            )
        }

        return await checkAndInsert(repo)
    }

    /// Check for duplicates and insert the repo.
    private func checkAndInsert(_ repo: ExtensionRepo) async -> Result {
        do {
            let existingRepos = try await repository.getAll()

            if existingRepos.contains(where: { $0.baseUrl == repo.baseUrl }) {
                return .repoAlreadyExists
            }

            if !repo.signingKeyFingerprint.isEmpty,
               let match = existingRepos.first(where: {
                   $0.signingKeyFingerprint == repo.signingKeyFingerprint
               }) {
                return .duplicateFingerprint(existing: match, new: repo)
            }
        } catch {
            return .error(error.localizedDescription)
        }

        do {
            try await repository.insert(repo: repo)
            return .success
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
