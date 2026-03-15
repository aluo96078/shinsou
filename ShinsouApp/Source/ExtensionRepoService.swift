import Foundation
import ShinsouDomain
import ShinsouSourceAPI

// MARK: - Network DTOs

/// Response shape from `{baseUrl}/repo.json`.
struct RepoMetaResponse: Decodable {
    let meta: RepoMeta

    struct RepoMeta: Decodable {
        let name: String
        let shortName: String?
        let website: String?
        let signingKeyFingerprint: String?
    }
}

// MARK: - ExtensionRepoService

/// Fetches repository metadata (`repo.json`) and extension indices (`index.min.json`) over the network.
final class ExtensionRepoService: Sendable {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Fetch repo metadata

    /// Fetches `{baseUrl}/repo.json` and returns an `ExtensionRepo` domain model.
    func fetchRepoDetails(baseUrl: String) async throws -> ExtensionRepo {
        let url = try buildURL(base: baseUrl, path: "repo.json")
        let (data, response) = try await session.data(from: url)
        try validateHTTPResponse(response)

        let decoded = try JSONDecoder().decode(RepoMetaResponse.self, from: data)
        return ExtensionRepo(
            baseUrl: baseUrl,
            name: decoded.meta.name,
            shortName: decoded.meta.shortName,
            website: decoded.meta.website ?? baseUrl,
            signingKeyFingerprint: decoded.meta.signingKeyFingerprint ?? ""
        )
    }

    // MARK: - Fetch extension index

    /// Fetches `{baseUrl}/index.min.json` and decodes an array of `ExtensionIndexEntry`.
    func fetchExtensionIndex(baseUrl: String) async throws -> [ExtensionIndexEntry] {
        let url = try buildURL(base: baseUrl, path: "index.min.json", bustCache: true)
        let (data, response) = try await session.data(from: url)
        try validateHTTPResponse(response)

        return try JSONDecoder().decode([ExtensionIndexEntry].self, from: data)
    }

    // MARK: - Fetch plugin index (community JS repo)

    /// Fetches `{baseUrl}/index.json` and decodes an array of `PluginIndexEntry`.
    func fetchPluginIndex(baseUrl: String) async throws -> [PluginIndexEntry] {
        let url = try buildURL(base: baseUrl, path: "index.json", bustCache: true)
        let (data, response) = try await session.data(from: url)
        try validateHTTPResponse(response)

        return try JSONDecoder().decode([PluginIndexEntry].self, from: data)
    }

    // MARK: - Download plugin script

    /// Downloads a JS plugin script from `{baseUrl}/{scriptUrl}`.
    func downloadPluginScript(baseUrl: String, scriptUrl: String) async throws -> Data {
        let url = try buildURL(base: baseUrl, path: scriptUrl, bustCache: true)
        let (data, response) = try await session.data(from: url)
        try validateHTTPResponse(response)
        return data
    }

    // MARK: - Download extension icon

    /// Fetches `{baseUrl}/icon/{pkgName}.png` and returns raw image data, or `nil` on failure.
    func fetchExtensionIcon(baseUrl: String, pkgName: String) async -> Data? {
        guard let url = try? buildURL(base: baseUrl, path: "icon/\(pkgName).png") else { return nil }
        return try? await session.data(from: url).0
    }

    // MARK: - Private helpers

    private func buildURL(base: String, path: String, bustCache: Bool = false) throws -> URL {
        let trimmed = base.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        var urlString = "\(trimmed)/\(path)"
        if bustCache {
            urlString += "?_t=\(Int(Date().timeIntervalSince1970))"
        }
        guard let url = URL(string: urlString) else {
            throw ExtensionRepoError.invalidUrl(base)
        }
        return url
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ExtensionRepoError.networkError("Invalid response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ExtensionRepoError.httpError(statusCode: http.statusCode)
        }
    }
}

// MARK: - Errors

enum ExtensionRepoError: Error, LocalizedError {
    case invalidUrl(String)
    case httpError(statusCode: Int)
    case networkError(String)
    case repoAlreadyExists(String)
    case duplicateFingerprint(existing: ExtensionRepo, new: ExtensionRepo)
    case invalidIndexUrl

    var errorDescription: String? {
        switch self {
        case .invalidUrl(let url):
            return "Invalid URL: \(url)"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .repoAlreadyExists(let url):
            return "Repository already exists: \(url)"
        case .duplicateFingerprint(let existing, _):
            return "A repository with the same signing key already exists: \(existing.name)"
        case .invalidIndexUrl:
            return "URL must end with /index.min.json"
        }
    }
}
