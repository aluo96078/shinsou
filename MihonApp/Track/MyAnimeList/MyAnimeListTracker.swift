import Foundation
import MihonDomain
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

// MARK: - MyAnimeListTracker

/// Tracker implementation for MyAnimeList (manga section).
///
/// Status mapping (MAL raw int stored in Track.status):
///   1 = reading
///   2 = completed
///   3 = on_hold
///   4 = dropped
///   6 = plan_to_read  (MAL uses 6, not 5)
///   7 = rereading     (MAL uses 7, not 6)
///
/// The generic TrackStatus enum uses 5=planToRead and 6=rereading;
/// conversion happens in statusToTrackStatus() / trackStatusToMalInt().
final class MyAnimeListTracker: Tracker {

    // MARK: - Tracker identity

    var id: Int       { 1 }
    var name: String  { "MyAnimeList" }
    var logoName: String { "mal" }

    // MARK: - Capabilities

    var supportsReadingDates: Bool    { true }
    var supportsPrivateTracking: Bool { false }
    var scoreFormat: TrackerScoreFormat { .point10 }

    // MARK: - OAuth / API constants

    /// Replace with your registered MAL client ID.
    private let clientId = "YOUR_MAL_CLIENT_ID"

    private let authBaseUrl  = "https://myanimelist.net/v1/oauth2/authorize"
    private let redirectUri  = "mihon://mal/oauth"

    // MARK: - Internals

    private let tokenStore: MALTokenStore
    let api: MyAnimeListApi

    /// Transient PKCE state kept between getAuthUrl() and handleAuthCallback().
    private var pendingCodeVerifier: String = ""

    init() {
        self.tokenStore = MALTokenStore(clientId: clientId)
        self.api        = MyAnimeListApi(tokenStore: tokenStore)
    }

    // MARK: - Auth state

    var isLoggedIn: Bool {
        tokenStore.hasToken
    }

    // MARK: - Status

    func getStatusList() -> [TrackStatus] {
        TrackStatus.allCases
    }

    func getCompletionStatus() -> TrackStatus {
        .completed
    }

    // MARK: - Score

    /// Returns ["0", "1", "2", ... "10"]
    func getScoreList() -> [String] {
        (0...10).map { "\($0)" }
    }

    func displayScore(score: Double) -> String {
        guard score > 0 else { return "-" }
        return "\(Int(score))"
    }

    /// Converts a list index (0–10) directly to the MAL score value (0–10).
    func indexToScore(index: Int) -> Double {
        Double(index.clamped(to: 0...10))
    }

    // MARK: - Operations

    func search(query: String) async throws -> [TrackSearch] {
        try await api.search(query: query)
    }

    /// Associates a Track with a remotely-found TrackSearch result and fetches
    /// the latest list status from MAL.
    func bind(track: Track, remoteSearch: TrackSearch) async throws -> Track {
        let bound = Track(
            id:              track.id,
            mangaId:         track.mangaId,
            trackerId:       self.id,
            remoteId:        remoteSearch.id,
            title:           remoteSearch.title,
            lastChapterRead: track.lastChapterRead,
            totalChapters:   remoteSearch.totalChapters,
            status:          malIntForTrackStatus(.reading),
            score:           track.score,
            remoteUrl:       "https://myanimelist.net/manga/\(remoteSearch.id)",
            startDate:       track.startDate,
            finishDate:      track.finishDate
        )
        // Fetch existing list status if the user already has this on their list.
        let refreshed = try await refresh(track: bound)
        return refreshed
    }

    /// Pushes local Track state to MAL and returns the refreshed Track.
    func update(track: Track) async throws -> Track {
        try await api.updateMangaStatus(track: track)
        return try await refresh(track: track)
    }

    /// Fetches the latest MAL list status and updates the Track.
    func refresh(track: Track) async throws -> Track {
        try await api.getListStatus(track: track)
    }

    // MARK: - Auth

    /// Builds the MAL OAuth authorization URL using PKCE.
    func getAuthUrl() -> String {
        let verifier  = PKCEHelper.generateCodeVerifier()
        let challenge = PKCEHelper.codeChallenge(for: verifier)
        pendingCodeVerifier = verifier

        var components = URLComponents(string: authBaseUrl)!
        components.queryItems = [
            URLQueryItem(name: "response_type",           value: "code"),
            URLQueryItem(name: "client_id",               value: clientId),
            URLQueryItem(name: "code_challenge",          value: challenge),
            URLQueryItem(name: "code_challenge_method",   value: "S256"),
            URLQueryItem(name: "redirect_uri",            value: redirectUri)
        ]
        return components.url?.absoluteString ?? authBaseUrl
    }

    /// Handles the OAuth callback URL, exchanges the code for tokens, and
    /// persists them via the token store.
    func handleAuthCallback(url: URL) async throws {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw MALApiError.invalidResponse(0)
        }

        let oauth = try await api.fetchAccessToken(
            clientId:     clientId,
            code:         code,
            codeVerifier: pendingCodeVerifier,
            redirectUri:  redirectUri
        )
        tokenStore.saveToken(oauth)
        pendingCodeVerifier = ""
    }

    func logout() {
        tokenStore.clearToken()
    }
}

// MARK: - Status Conversion Helpers

extension MyAnimeListTracker {

    /// MAL-specific integer values stored in Track.status.
    enum MALStatusInt {
        static let reading     = 1
        static let completed   = 2
        static let onHold      = 3
        static let dropped     = 4
        static let planToRead  = 6  // MAL uses 6 (not 5)
        static let rereading   = 7  // MAL uses 7 (not 6)
    }

    /// Returns the MAL raw int for a given generic TrackStatus.
    func malIntForTrackStatus(_ status: TrackStatus) -> Int {
        switch status {
        case .reading:    return MALStatusInt.reading
        case .completed:  return MALStatusInt.completed
        case .onHold:     return MALStatusInt.onHold
        case .dropped:    return MALStatusInt.dropped
        case .planToRead: return MALStatusInt.planToRead
        case .rereading:  return MALStatusInt.rereading
        }
    }

    /// Returns the generic TrackStatus for a MAL raw int.
    func statusToTrackStatus(_ malInt: Int) -> TrackStatus {
        switch malInt {
        case MALStatusInt.reading:    return .reading
        case MALStatusInt.completed:  return .completed
        case MALStatusInt.onHold:     return .onHold
        case MALStatusInt.dropped:    return .dropped
        case MALStatusInt.planToRead: return .planToRead
        case MALStatusInt.rereading:  return .rereading
        default:                      return .planToRead
        }
    }
}

// MARK: - Comparable clamp helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
