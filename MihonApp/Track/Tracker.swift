import Foundation
import MihonDomain

public enum TrackerScoreFormat: Sendable {
    case point10
    case point100
    case point5
    case point10Decimal
    case point3  // smiley
}

public protocol Tracker: AnyObject, Sendable {
    var id: Int { get }
    var name: String { get }
    var logoName: String { get }
    var supportsReadingDates: Bool { get }
    var supportsPrivateTracking: Bool { get }
    var scoreFormat: TrackerScoreFormat { get }

    var isLoggedIn: Bool { get }

    // Status
    func getStatusList() -> [TrackStatus]
    func getCompletionStatus() -> TrackStatus

    // Score
    func getScoreList() -> [String]
    func displayScore(score: Double) -> String
    func indexToScore(index: Int) -> Double

    // Operations
    func search(query: String) async throws -> [TrackSearch]
    func bind(track: Track, remoteSearch: TrackSearch) async throws -> Track
    func update(track: Track) async throws -> Track
    func refresh(track: Track) async throws -> Track

    // Auth
    func getAuthUrl() -> String
    func handleAuthCallback(url: URL) async throws
    func logout()
}

extension Tracker {
    public var supportsReadingDates: Bool { false }
    public var supportsPrivateTracking: Bool { false }
    public var scoreFormat: TrackerScoreFormat { .point10 }
}
