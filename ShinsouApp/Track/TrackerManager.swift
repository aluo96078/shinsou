import Foundation
import ShinsouDomain

@MainActor
public final class TrackerManager: ObservableObject {
    public static let shared = TrackerManager()

    @Published public private(set) var trackers: [any Tracker] = []

    private init() {
        trackers = [
            MyAnimeListTracker(),
            AniListTracker()
        ]
    }

    public func tracker(forId id: Int) -> (any Tracker)? {
        trackers.first { $0.id == id }
    }

    public var loggedInTrackers: [any Tracker] {
        trackers.filter { $0.isLoggedIn }
    }
}
