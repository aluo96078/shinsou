import Foundation

public struct LibraryFilter: Equatable, Sendable {
    public var downloaded: TriState
    public var unread: TriState
    public var started: TriState
    public var bookmarked: TriState
    public var completed: TriState

    /// Per-tracker filter keyed by tracker ID (e.g. MyAnimeList = 1, AniList = 2, …).
    /// A missing key is equivalent to `.disabled`.
    public var trackerFilters: [Int: TriState]

    public init(
        downloaded: TriState = .disabled,
        unread: TriState = .disabled,
        started: TriState = .disabled,
        bookmarked: TriState = .disabled,
        completed: TriState = .disabled,
        trackerFilters: [Int: TriState] = [:]
    ) {
        self.downloaded = downloaded
        self.unread = unread
        self.started = started
        self.bookmarked = bookmarked
        self.completed = completed
        self.trackerFilters = trackerFilters
    }

    public var hasActiveFilters: Bool {
        downloaded != .disabled || unread != .disabled ||
        started != .disabled || bookmarked != .disabled || completed != .disabled ||
        trackerFilters.values.contains { $0 != .disabled }
    }

    /// Returns the tracker filter state for the given tracker ID.
    public func trackerFilter(for trackerId: Int) -> TriState {
        trackerFilters[trackerId] ?? .disabled
    }

    /// Returns a new `LibraryFilter` with the tracker filter for the given ID updated.
    public func withTrackerFilter(_ state: TriState, for trackerId: Int) -> LibraryFilter {
        var copy = self
        if state == .disabled {
            copy.trackerFilters.removeValue(forKey: trackerId)
        } else {
            copy.trackerFilters[trackerId] = state
        }
        return copy
    }

    public enum TriState: Int, Sendable {
        case disabled = 0
        case include = 1
        case exclude = 2

        public func next() -> TriState {
            switch self {
            case .disabled: return .include
            case .include: return .exclude
            case .exclude: return .disabled
            }
        }
    }
}

// MARK: - Well-known tracker IDs (mirrors Tachiyomi/Mihon conventions)

public enum TrackerID {
    public static let myAnimeList: Int = 1
    public static let aniList: Int    = 2
    public static let kitsu: Int      = 3
    public static let shikimori: Int  = 4
    public static let bangumi: Int    = 5
    public static let mangaUpdates: Int = 6

    public static let all: [(id: Int, name: String)] = [
        (myAnimeList, "MyAnimeList"),
        (aniList,     "AniList"),
        (kitsu,       "Kitsu"),
        (shikimori,   "Shikimori"),
        (bangumi,     "Bangumi"),
        (mangaUpdates, "MangaUpdates"),
    ]
}
