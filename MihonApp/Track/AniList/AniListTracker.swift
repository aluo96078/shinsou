import Foundation
import MihonDomain

// MARK: - AniListTracker

final class AniListTracker: Tracker {

    // MARK: - Constants

    private static let clientId = "16329"
    private static let authBaseUrl = "https://anilist.co/api/v2/oauth/authorize"

    private enum UserDefaultsKey {
        static let accessToken  = "anilist_access_token"
        static let tokenType    = "anilist_token_type"
        static let expiresIn    = "anilist_expires_in"
        static let createdAt    = "anilist_created_at"
        static let scoreFormat  = "anilist_score_format"
    }

    // MARK: - Tracker identity

    let id = 2
    let name = "AniList"
    let logoName = "anilist"
    let supportsReadingDates = true
    let supportsPrivateTracking = true

    // MARK: - Dependencies

    private let api: AniListApi

    // MARK: - Init

    init() {
        api = AniListApi { [weak _self = () as AnyObject?] in
            UserDefaults.standard.string(forKey: UserDefaultsKey.accessToken)
        }
    }

    // MARK: - Score format

    var scoreFormat: TrackerScoreFormat {
        let raw = UserDefaults.standard.string(forKey: UserDefaultsKey.scoreFormat) ?? ""
        return Self.parseScoreFormat(raw)
    }

    private static func parseScoreFormat(_ raw: String) -> TrackerScoreFormat {
        switch raw {
        case "POINT_100":          return .point100
        case "POINT_10_DECIMAL":   return .point10Decimal
        case "POINT_5":            return .point5
        case "POINT_3":            return .point3
        default:                   return .point10
        }
    }

    // MARK: - Auth

    var isLoggedIn: Bool {
        guard let token = UserDefaults.standard.string(forKey: UserDefaultsKey.accessToken),
              !token.isEmpty else { return false }
        let expiresIn  = UserDefaults.standard.object(forKey: UserDefaultsKey.expiresIn) as? Int64 ?? 0
        let createdAt  = UserDefaults.standard.object(forKey: UserDefaultsKey.createdAt) as? Int64 ?? 0
        let oauth = ALOAuth(
            accessToken: token,
            tokenType: UserDefaults.standard.string(forKey: UserDefaultsKey.tokenType) ?? "Bearer",
            expiresIn: expiresIn,
            createdAt: createdAt
        )
        return !oauth.isExpired
    }

    func getAuthUrl() -> String {
        "\(Self.authBaseUrl)?client_id=\(Self.clientId)&response_type=token"
    }

    /// Parses the access token from the implicit-flow redirect URI fragment.
    func handleAuthCallback(url: URL) async throws {
        // AniList returns the token in the URL fragment:
        // mihon://anilist-auth#access_token=XXX&token_type=Bearer&expires_in=YYY
        guard let fragment = url.fragment else {
            throw AniListError.notAuthenticated
        }

        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                params[String(kv[0])] = String(kv[1])
            }
        }

        guard let accessToken = params["access_token"], !accessToken.isEmpty else {
            throw AniListError.notAuthenticated
        }

        let tokenType = params["token_type"] ?? "Bearer"
        let expiresIn = Int64(params["expires_in"] ?? "0") ?? 0
        let createdAt = Int64(Date().timeIntervalSince1970)

        let defaults = UserDefaults.standard
        defaults.set(accessToken, forKey: UserDefaultsKey.accessToken)
        defaults.set(tokenType,   forKey: UserDefaultsKey.tokenType)
        defaults.set(expiresIn,   forKey: UserDefaultsKey.expiresIn)
        defaults.set(createdAt,   forKey: UserDefaultsKey.createdAt)

        // Fetch and persist score format preference
        let (_, scoreFormatRaw) = try await api.getCurrentUser()
        defaults.set(scoreFormatRaw, forKey: UserDefaultsKey.scoreFormat)
    }

    func logout() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKey.accessToken)
        defaults.removeObject(forKey: UserDefaultsKey.tokenType)
        defaults.removeObject(forKey: UserDefaultsKey.expiresIn)
        defaults.removeObject(forKey: UserDefaultsKey.createdAt)
        defaults.removeObject(forKey: UserDefaultsKey.scoreFormat)
    }

    // MARK: - Status

    func getStatusList() -> [TrackStatus] {
        [.reading, .completed, .onHold, .dropped, .planToRead, .rereading]
    }

    func getCompletionStatus() -> TrackStatus { .completed }

    // MARK: - Score helpers

    func getScoreList() -> [String] {
        switch scoreFormat {
        case .point10:
            return ["0"] + (1...10).map { String($0) }
        case .point100:
            return ["0"] + (1...100).map { String($0) }
        case .point5:
            return ["0", "1 ★", "2 ★★", "3 ★★★", "4 ★★★★", "5 ★★★★★"]
        case .point10Decimal:
            // 0.0, 0.5 … 10.0  (21 entries)
            return stride(from: 0.0, through: 10.0, by: 0.5).map { v in
                v.truncatingRemainder(dividingBy: 1) == 0
                    ? String(Int(v))
                    : String(format: "%.1f", v)
            }
        case .point3:
            return ["0", ":( 1", ":| 2", ":) 3"]
        }
    }

    func displayScore(score: Double) -> String {
        guard score > 0 else { return "-" }
        switch scoreFormat {
        case .point10, .point100, .point3:
            return String(Int(score))
        case .point10Decimal:
            return score.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(score))
                : String(format: "%.1f", score)
        case .point5:
            return String(repeating: "★", count: Int(score))
        }
    }

    /// Maps a display-list index (from getScoreList) back to a raw score value.
    func indexToScore(index: Int) -> Double {
        switch scoreFormat {
        case .point10:
            // index 0 → 0, index 1 → 1 … index 10 → 10
            return Double(index)
        case .point100:
            return Double(index)
        case .point5:
            return Double(index)
        case .point10Decimal:
            // 0.0, 0.5, 1.0 …
            return Double(index) * 0.5
        case .point3:
            return Double(index)
        }
    }

    // MARK: - Operations

    func search(query: String) async throws -> [TrackSearch] {
        try await api.search(query: query)
    }

    func bind(track: Track, remoteSearch: TrackSearch) async throws -> Track {
        // Create initial list entry on AniList; remoteId becomes the library entry id
        let libraryId = try await api.addManga(track: track)
        return Track(
            id: track.id,
            mangaId: track.mangaId,
            trackerId: self.id,
            remoteId: libraryId,
            title: remoteSearch.title,
            lastChapterRead: track.lastChapterRead,
            totalChapters: remoteSearch.totalChapters,
            status: TrackStatus.reading.rawValue,
            score: 0,
            remoteUrl: "https://anilist.co/manga/\(remoteSearch.id)",
            startDate: 0,
            finishDate: 0
        )
    }

    func update(track: Track) async throws -> Track {
        try await api.updateManga(track: track)
        return track
    }

    func refresh(track: Track) async throws -> Track {
        // AniList has no separate "fetch single entry" query in the minimal API surface;
        // we perform an update to sync and return the track unchanged.
        try await api.updateManga(track: track)
        return track
    }
}
