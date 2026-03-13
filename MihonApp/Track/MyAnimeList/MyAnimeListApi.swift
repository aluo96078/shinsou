import Foundation
import MihonDomain

// MARK: - Error Types

enum MALApiError: LocalizedError {
    case notLoggedIn
    case invalidResponse(Int)
    case decodingError(String)
    case networkError(Error)
    case tokenRefreshFailed

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:            return "Not logged in to MyAnimeList"
        case .invalidResponse(let c): return "MAL API returned status \(c)"
        case .decodingError(let m):   return "Failed to decode MAL response: \(m)"
        case .networkError(let e):    return "Network error: \(e.localizedDescription)"
        case .tokenRefreshFailed:     return "Failed to refresh MAL access token"
        }
    }
}

// MARK: - Response Models (private)

private struct MALMangaListResponse: Decodable {
    let data: [MALMangaNode]
}

private struct MALMangaNode: Decodable {
    let node: MALManga
}

private struct MALManga: Decodable {
    let id: Int
    let title: String
    let synopsis: String?
    let numChapters: Int?
    let mainPicture: MALPicture?
    let status: String?
    let mediaType: String?
    let startDate: String?
    let myListStatus: MALMyListStatus?

    enum CodingKeys: String, CodingKey {
        case id, title, synopsis, status
        case numChapters  = "num_chapters"
        case mainPicture  = "main_picture"
        case mediaType    = "media_type"
        case startDate    = "start_date"
        case myListStatus = "my_list_status"
    }
}

private struct MALPicture: Decodable {
    let large: String?
    let medium: String?
}

private struct MALMyListStatus: Decodable {
    let status: String?
    let score: Int?
    let numChaptersRead: Int?
    let startDate: String?
    let finishDate: String?

    enum CodingKeys: String, CodingKey {
        case status, score
        case numChaptersRead = "num_chapters_read"
        case startDate       = "start_date"
        case finishDate      = "finish_date"
    }
}

private struct MALSingleMangaResponse: Decodable {
    let id: Int
    let title: String
    let synopsis: String?
    let numChapters: Int?
    let mainPicture: MALPicture?
    let status: String?
    let mediaType: String?
    let startDate: String?
    let myListStatus: MALMyListStatus?

    enum CodingKeys: String, CodingKey {
        case id, title, synopsis, status
        case numChapters  = "num_chapters"
        case mainPicture  = "main_picture"
        case mediaType    = "media_type"
        case startDate    = "start_date"
        case myListStatus = "my_list_status"
    }
}

// MARK: - MAL API Client

final class MyAnimeListApi: Sendable {

    static let baseUrl = "https://api.myanimelist.net/v2"

    private let tokenStore: MALTokenStore

    init(tokenStore: MALTokenStore) {
        self.tokenStore = tokenStore
    }

    // MARK: - Public API

    /// Search for manga by title.
    func search(query: String) async throws -> [TrackSearch] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(Self.baseUrl)/manga?q=\(encoded)&nsfw=true&fields=id,title,synopsis,num_chapters,main_picture,status,media_type,start_date&limit=25"
        guard let url = URL(string: urlString) else { return [] }

        let data = try await authorizedRequest(url: url)
        do {
            let response = try JSONDecoder().decode(MALMangaListResponse.self, from: data)
            return response.data.map { toTrackSearch($0.node) }
        } catch {
            throw MALApiError.decodingError(error.localizedDescription)
        }
    }

    /// Fetch details for a single manga entry.
    func getMangaDetails(remoteId: Int64) async throws -> TrackSearch {
        let urlString = "\(Self.baseUrl)/manga/\(remoteId)?fields=id,title,synopsis,num_chapters,main_picture,status,media_type,start_date,my_list_status"
        guard let url = URL(string: urlString) else {
            throw MALApiError.invalidResponse(0)
        }

        let data = try await authorizedRequest(url: url)
        do {
            let manga = try JSONDecoder().decode(MALSingleMangaResponse.self, from: data)
            return toTrackSearchFromSingle(manga)
        } catch {
            throw MALApiError.decodingError(error.localizedDescription)
        }
    }

    /// Fetch the current list status and return an updated Track.
    func getListStatus(track: Track) async throws -> Track {
        let urlString = "\(Self.baseUrl)/manga/\(track.remoteId)?fields=my_list_status"
        guard let url = URL(string: urlString) else {
            throw MALApiError.invalidResponse(0)
        }

        let data = try await authorizedRequest(url: url)

        struct Wrapper: Decodable {
            let myListStatus: MALMyListStatus?
            enum CodingKeys: String, CodingKey { case myListStatus = "my_list_status" }
        }

        let wrapper = try JSONDecoder().decode(Wrapper.self, from: data)
        guard let listStatus = wrapper.myListStatus else { return track }

        return applyListStatus(listStatus, to: track)
    }

    /// Create or update the reading status for a manga entry.
    func updateMangaStatus(track: Track) async throws {
        let urlString = "\(Self.baseUrl)/manga/\(track.remoteId)/my_list_status"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        try await addAuthHeader(to: &request)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var params: [String: String] = [
            "num_chapters_read": "\(Int(track.lastChapterRead))",
            "score": "\(Int(track.score))"
        ]

        let malStatus = toMALStatus(trackStatus: track.status)
        params["status"] = malStatus

        if track.startDate > 0 {
            params["start_date"] = formatMALDate(timestamp: track.startDate)
        }
        if track.finishDate > 0 {
            params["finish_date"] = formatMALDate(timestamp: track.finishDate)
        }

        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw MALApiError.invalidResponse(code)
        }
    }

    /// Delete a manga from the user's list.
    func deleteMangaStatus(remoteId: Int64) async throws {
        let urlString = "\(Self.baseUrl)/manga/\(remoteId)/my_list_status"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        try await addAuthHeader(to: &request)

        let (_, response) = try await URLSession.shared.data(for: request)
        // 200 and 404 are both acceptable (404 = entry didn't exist)
        if let http = response as? HTTPURLResponse, http.statusCode != 200, http.statusCode != 404 {
            throw MALApiError.invalidResponse(http.statusCode)
        }
    }

    // MARK: - OAuth Token Exchange

    /// Exchange an authorization code for tokens.
    func fetchAccessToken(
        clientId: String,
        code: String,
        codeVerifier: String,
        redirectUri: String
    ) async throws -> MALOAuth {
        let tokenUrl = URL(string: "https://myanimelist.net/v1/oauth2/token")!
        var request = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "client_id":     clientId,
            "code":          code,
            "code_verifier": codeVerifier,
            "grant_type":    "authorization_code",
            "redirect_uri":  redirectUri
        ]
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        return try await decodeToken(request: request)
    }

    /// Refresh an expired access token.
    func refreshAccessToken(clientId: String, oauth: MALOAuth) async throws -> MALOAuth {
        let tokenUrl = URL(string: "https://myanimelist.net/v1/oauth2/token")!
        var request = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "client_id":     clientId,
            "grant_type":    "refresh_token",
            "refresh_token": oauth.refreshToken
        ]
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        return try await decodeToken(request: request)
    }

    // MARK: - Private Helpers

    private func authorizedRequest(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        try await addAuthHeader(to: &request)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw MALApiError.invalidResponse(code)
            }
            return data
        } catch let error as MALApiError {
            throw error
        } catch {
            throw MALApiError.networkError(error)
        }
    }

    private func addAuthHeader(to request: inout URLRequest) async throws {
        guard var oauth = tokenStore.loadToken() else {
            throw MALApiError.notLoggedIn
        }
        if oauth.isExpired {
            let clientId = tokenStore.clientId
            oauth = try await refreshAccessToken(clientId: clientId, oauth: oauth)
            tokenStore.saveToken(oauth)
        }
        request.setValue("Bearer \(oauth.accessToken)", forHTTPHeaderField: "Authorization")
    }

    private func decodeToken(request: URLRequest) async throws -> MALOAuth {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                throw MALApiError.invalidResponse(code)
            }

            // MAL does not include created_at; we inject the current timestamp.
            var json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            if json["created_at"] == nil {
                json["created_at"] = Int64(Date().timeIntervalSince1970)
            }
            let patched = try JSONSerialization.data(withJSONObject: json)

            let decoder = JSONDecoder()
            return try decoder.decode(MALOAuth.self, from: patched)
        } catch let error as MALApiError {
            throw error
        } catch {
            throw MALApiError.tokenRefreshFailed
        }
    }

    // MARK: - Mapping Helpers

    private func toTrackSearch(_ manga: MALManga) -> TrackSearch {
        TrackSearch(
            id:               Int64(manga.id),
            title:            manga.title,
            totalChapters:    manga.numChapters ?? 0,
            coverUrl:         manga.mainPicture?.large ?? manga.mainPicture?.medium ?? "",
            summary:          manga.synopsis ?? "",
            publishingStatus: localizedStatus(manga.status),
            publishingType:   manga.mediaType ?? "",
            startDate:        manga.startDate ?? ""
        )
    }

    private func toTrackSearchFromSingle(_ manga: MALSingleMangaResponse) -> TrackSearch {
        TrackSearch(
            id:               Int64(manga.id),
            title:            manga.title,
            totalChapters:    manga.numChapters ?? 0,
            coverUrl:         manga.mainPicture?.large ?? manga.mainPicture?.medium ?? "",
            summary:          manga.synopsis ?? "",
            publishingStatus: localizedStatus(manga.status),
            publishingType:   manga.mediaType ?? "",
            startDate:        manga.startDate ?? ""
        )
    }

    private func localizedStatus(_ status: String?) -> String {
        switch status {
        case "currently_publishing": return "Publishing"
        case "finished":             return "Finished"
        case "not_yet_published":    return "Not Yet Published"
        case "discontinued":         return "Discontinued"
        case "on_hiatus":            return "On Hiatus"
        default:                     return status ?? ""
        }
    }

    /// Maps internal status int (MAL-specific) back to MAL's string status.
    private func toMALStatus(trackStatus: Int) -> String {
        // MAL raw values used in MyAnimeListTracker:
        // 1=reading, 2=completed, 3=on_hold, 4=dropped, 6=plan_to_read, 7=rereading
        switch trackStatus {
        case 1: return "reading"
        case 2: return "completed"
        case 3: return "on_hold"
        case 4: return "dropped"
        case 6: return "plan_to_read"
        case 7: return "rereading"
        default: return "reading"
        }
    }

    private func applyListStatus(_ listStatus: MALMyListStatus, to track: Track) -> Track {
        let status = fromMALStatus(listStatus.status)
        let score  = Double(listStatus.score ?? 0)
        let chRead = Double(listStatus.numChaptersRead ?? 0)
        let start  = parseMALDate(listStatus.startDate) ?? track.startDate
        let finish = parseMALDate(listStatus.finishDate) ?? track.finishDate

        return Track(
            id:              track.id,
            mangaId:         track.mangaId,
            trackerId:       track.trackerId,
            remoteId:        track.remoteId,
            title:           track.title,
            lastChapterRead: chRead,
            totalChapters:   track.totalChapters,
            status:          status,
            score:           score,
            remoteUrl:       track.remoteUrl,
            startDate:       start,
            finishDate:      finish
        )
    }

    /// Maps MAL's string status to our internal MAL-specific int.
    private func fromMALStatus(_ status: String?) -> Int {
        switch status {
        case "reading":       return 1
        case "completed":     return 2
        case "on_hold":       return 3
        case "dropped":       return 4
        case "plan_to_read":  return 6
        case "rereading":     return 7
        default:              return 6  // plan_to_read as default
        }
    }

    /// Parses a MAL date string "YYYY-MM-DD" to a Unix timestamp (seconds, start of day UTC).
    func parseMALDate(_ dateString: String?) -> Int64? {
        guard let dateString, !dateString.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: dateString).map { Int64($0.timeIntervalSince1970) }
    }

    /// Formats a Unix timestamp to MAL's "YYYY-MM-DD" format.
    func formatMALDate(timestamp: Int64) -> String {
        guard timestamp > 0 else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }
}

// MARK: - Token Store

/// Abstracts UserDefaults access so it can be injected / tested.
final class MALTokenStore: Sendable {
    private let defaults: UserDefaults
    let clientId: String

    private enum Keys {
        static let accessToken  = "mal_access_token"
        static let refreshToken = "mal_refresh_token"
        static let tokenType    = "mal_token_type"
        static let expiresIn    = "mal_expires_in"
        static let createdAt    = "mal_created_at"
    }

    init(clientId: String, defaults: UserDefaults = .standard) {
        self.clientId = clientId
        self.defaults = defaults
    }

    func saveToken(_ oauth: MALOAuth) {
        defaults.set(oauth.accessToken,  forKey: Keys.accessToken)
        defaults.set(oauth.refreshToken, forKey: Keys.refreshToken)
        defaults.set(oauth.tokenType,    forKey: Keys.tokenType)
        defaults.set(oauth.expiresIn,    forKey: Keys.expiresIn)
        defaults.set(oauth.createdAt,    forKey: Keys.createdAt)
    }

    func loadToken() -> MALOAuth? {
        guard
            let access  = defaults.string(forKey: Keys.accessToken),
            let refresh = defaults.string(forKey: Keys.refreshToken),
            let type    = defaults.string(forKey: Keys.tokenType),
            !access.isEmpty
        else { return nil }

        let expiresIn = defaults.integer(forKey: Keys.expiresIn)
        let createdAt = defaults.object(forKey: Keys.createdAt) as? Int64
                        ?? Int64(defaults.double(forKey: Keys.createdAt))

        return MALOAuth(
            tokenType:    type,
            accessToken:  access,
            refreshToken: refresh,
            expiresIn:    expiresIn,
            createdAt:    createdAt
        )
    }

    func clearToken() {
        [Keys.accessToken, Keys.refreshToken, Keys.tokenType].forEach {
            defaults.removeObject(forKey: $0)
        }
        defaults.removeObject(forKey: Keys.expiresIn)
        defaults.removeObject(forKey: Keys.createdAt)
    }

    var hasToken: Bool {
        guard let token = defaults.string(forKey: Keys.accessToken) else { return false }
        return !token.isEmpty
    }
}
