import Foundation

public struct LibrarySort: Equatable, Sendable {
    public let type: SortType
    public let direction: Direction
    /// Seed used for deterministic shuffling when `type == .random`.
    /// Generate a new seed (e.g. via `UInt64.random(in: 0...UInt64.max)`) to reshuffle.
    public let randomSeed: UInt64

    public init(
        type: SortType = .alphabetical,
        direction: Direction = .ascending,
        randomSeed: UInt64 = 0
    ) {
        self.type = type
        self.direction = direction
        self.randomSeed = randomSeed
    }

    /// Convenience: returns a copy with a freshly-randomised seed.
    public func reshuffled() -> LibrarySort {
        LibrarySort(type: type, direction: direction, randomSeed: UInt64.random(in: 0...UInt64.max))
    }

    public enum SortType: Int, CaseIterable, Sendable {
        case alphabetical = 0
        case lastRead = 1
        case lastUpdate = 2
        case unreadCount = 3
        case totalChapters = 4
        case latestChapter = 5
        case chapterFetchDate = 6
        case dateAdded = 7
        case trackerMean = 8
        case random = 9

        public var displayName: String {
            switch self {
            case .alphabetical: return "Alphabetical"
            case .lastRead: return "Last read"
            case .lastUpdate: return "Last update"
            case .unreadCount: return "Unread count"
            case .totalChapters: return "Total chapters"
            case .latestChapter: return "Latest chapter"
            case .chapterFetchDate: return "Chapter fetch date"
            case .dateAdded: return "Date added"
            case .trackerMean: return "Tracker mean score"
            case .random: return "Random"
            }
        }
    }

    public enum Direction: Int, Sendable {
        case ascending = 0
        case descending = 1

        public var isAscending: Bool { self == .ascending }

        public func toggled() -> Direction {
            self == .ascending ? .descending : .ascending
        }
    }
}
