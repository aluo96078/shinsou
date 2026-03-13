import Foundation
import MihonDomain

// MARK: - GraphQL Queries & Mutations

private enum AniListQuery {
    static let searchManga = """
    query ($search: String) {
      Page(perPage: 25) {
        media(search: $search, type: MANGA) {
          id
          title { romaji }
          chapters
          coverImage { large }
          description(asHtml: false)
          status
          format
          startDate { year month day }
        }
      }
    }
    """

    static let addManga = """
    mutation ($mangaId: Int, $status: MediaListStatus) {
      SaveMediaListEntry(mediaId: $mangaId, status: $status) {
        id
      }
    }
    """

    static let updateManga = """
    mutation (
      $id: Int,
      $status: MediaListStatus,
      $score: Float,
      $progress: Int,
      $startedAt: FuzzyDateInput,
      $completedAt: FuzzyDateInput,
      $private: Boolean
    ) {
      SaveMediaListEntry(
        id: $id,
        status: $status,
        score: $score,
        progress: $progress,
        startedAt: $startedAt,
        completedAt: $completedAt,
        private: $private
      ) {
        id
      }
    }
    """

    static let deleteManga = """
    mutation ($id: Int) {
      DeleteMediaListEntry(id: $id) {
        deleted
      }
    }
    """

    static let currentUser = """
    query {
      Viewer {
        id
        mediaListOptions {
          scoreFormat
        }
      }
    }
    """
}

// MARK: - Response Models

private struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

private struct GraphQLError: Decodable {
    let message: String
}

private struct SearchResponse: Decodable {
    struct Page: Decodable {
        let media: [ALManga]
    }
    let Page: Page
}

private struct ALManga: Decodable {
    struct Title: Decodable {
        let romaji: String?
    }
    struct CoverImage: Decodable {
        let large: String?
    }
    struct FuzzyDate: Decodable {
        let year: Int?
        let month: Int?
        let day: Int?
    }
    let id: Int
    let title: Title
    let chapters: Int?
    let coverImage: CoverImage?
    let description: String?
    let status: String?
    let format: String?
    let startDate: FuzzyDate?
}

private struct SaveEntryResponse: Decodable {
    struct SaveMediaListEntry: Decodable {
        let id: Int
    }
    let SaveMediaListEntry: SaveMediaListEntry
}

private struct DeleteEntryResponse: Decodable {
    struct DeleteMediaListEntry: Decodable {
        let deleted: Bool
    }
    let DeleteMediaListEntry: DeleteMediaListEntry
}

private struct ViewerResponse: Decodable {
    struct Viewer: Decodable {
        struct MediaListOptions: Decodable {
            let scoreFormat: String
        }
        let id: Int
        let mediaListOptions: MediaListOptions
    }
    let Viewer: Viewer
}

// MARK: - FuzzyDate helper

private func fuzzyDateInput(from epoch: Int64) -> [String: Int?]? {
    guard epoch > 0 else { return nil }
    let date = Date(timeIntervalSince1970: TimeInterval(epoch) / 1000)
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return [
        "year":  components.year,
        "month": components.month,
        "day":   components.day
    ]
}

// MARK: - AniList API Client

final class AniListApi: Sendable {

    private let endpoint = "https://graphql.anilist.co/"
    private let tokenProvider: @Sendable () -> String?

    init(tokenProvider: @escaping @Sendable () -> String?) {
        self.tokenProvider = tokenProvider
    }

    // MARK: Public API

    func search(query: String) async throws -> [TrackSearch] {
        let variables: [String: Any] = ["search": query]
        let wrapper: GraphQLResponse<SearchResponse> = try await execute(
            query: AniListQuery.searchManga,
            variables: variables
        )
        try throwIfErrors(wrapper.errors)
        return (wrapper.data?.Page.media ?? []).map { manga in
            let date = formatFuzzyDate(manga.startDate)
            return TrackSearch(
                id: Int64(manga.id),
                title: manga.title.romaji ?? "",
                totalChapters: manga.chapters ?? 0,
                coverUrl: manga.coverImage?.large ?? "",
                summary: manga.description ?? "",
                publishingStatus: manga.status ?? "",
                publishingType: manga.format ?? "",
                startDate: date
            )
        }
    }

    func addManga(track: Track) async throws -> Int64 {
        let statusString = AniListStatusConverter.toAniList(status: track.status)
        let variables: [String: Any] = [
            "mangaId": Int(track.remoteId),
            "status": statusString
        ]
        let wrapper: GraphQLResponse<SaveEntryResponse> = try await execute(
            query: AniListQuery.addManga,
            variables: variables
        )
        try throwIfErrors(wrapper.errors)
        guard let entryId = wrapper.data?.SaveMediaListEntry.id else {
            throw AniListError.missingData("SaveMediaListEntry returned no id")
        }
        return Int64(entryId)
    }

    func updateManga(track: Track) async throws {
        var variables: [String: Any] = [
            "id": Int(track.remoteId),
            "status": AniListStatusConverter.toAniList(status: track.status),
            "score": track.score,
            "progress": Int(track.lastChapterRead)
        ]

        if let startedAt = fuzzyDateInput(from: track.startDate) {
            variables["startedAt"] = startedAt
        }
        if let completedAt = fuzzyDateInput(from: track.finishDate) {
            variables["completedAt"] = completedAt
        }

        let wrapper: GraphQLResponse<SaveEntryResponse> = try await execute(
            query: AniListQuery.updateManga,
            variables: variables
        )
        try throwIfErrors(wrapper.errors)
    }

    func deleteManga(libraryId: Int64) async throws {
        let variables: [String: Any] = ["id": Int(libraryId)]
        let wrapper: GraphQLResponse<DeleteEntryResponse> = try await execute(
            query: AniListQuery.deleteManga,
            variables: variables
        )
        try throwIfErrors(wrapper.errors)
    }

    /// Returns (userId, scoreFormat string).
    func getCurrentUser() async throws -> (Int, String) {
        let wrapper: GraphQLResponse<ViewerResponse> = try await execute(
            query: AniListQuery.currentUser,
            variables: [:]
        )
        try throwIfErrors(wrapper.errors)
        guard let viewer = wrapper.data?.Viewer else {
            throw AniListError.missingData("Viewer data missing")
        }
        return (viewer.id, viewer.mediaListOptions.scoreFormat)
    }

    // MARK: Private helpers

    private func execute<T: Decodable>(
        query: String,
        variables: [String: Any]
    ) async throws -> GraphQLResponse<T> {
        guard let url = URL(string: endpoint) else {
            throw AniListError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = ["query": query, "variables": variables]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw AniListError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(GraphQLResponse<T>.self, from: data)
    }

    private func throwIfErrors(_ errors: [GraphQLError]?) throws {
        guard let first = errors?.first else { return }
        throw AniListError.graphQLError(first.message)
    }

    private func formatFuzzyDate(_ date: ALManga.FuzzyDate?) -> String {
        guard let date else { return "" }
        let y = date.year.map { String($0) } ?? "????"
        let m = date.month.map { String(format: "%02d", $0) } ?? "??"
        let d = date.day.map { String(format: "%02d", $0) } ?? "??"
        return "\(y)-\(m)-\(d)"
    }
}

// MARK: - Status Converter

enum AniListStatusConverter {
    static func toAniList(status: Int) -> String {
        switch status {
        case 1: return "CURRENT"
        case 2: return "COMPLETED"
        case 3: return "PAUSED"
        case 4: return "DROPPED"
        case 5: return "PLANNING"
        case 6: return "REPEATING"
        default: return "PLANNING"
        }
    }

    static func fromAniList(_ status: String) -> Int {
        switch status {
        case "CURRENT":   return 1
        case "COMPLETED": return 2
        case "PAUSED":    return 3
        case "DROPPED":   return 4
        case "PLANNING":  return 5
        case "REPEATING": return 6
        default:          return 5
        }
    }
}

// MARK: - Errors

enum AniListError: Error, LocalizedError {
    case invalidURL
    case httpError(Int)
    case graphQLError(String)
    case missingData(String)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .invalidURL:            return "Invalid AniList API URL."
        case .httpError(let code):   return "HTTP error \(code)."
        case .graphQLError(let msg): return "AniList GraphQL error: \(msg)"
        case .missingData(let msg):  return "Missing data: \(msg)"
        case .notAuthenticated:      return "Not authenticated with AniList."
        }
    }
}
