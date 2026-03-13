import Foundation

public enum TrackStatus: Int, CaseIterable, Sendable {
    case reading = 1
    case completed = 2
    case onHold = 3
    case dropped = 4
    case planToRead = 5
    case rereading = 6

    public var displayName: String {
        switch self {
        case .reading: return "Reading"
        case .completed: return "Completed"
        case .onHold: return "On Hold"
        case .dropped: return "Dropped"
        case .planToRead: return "Plan to Read"
        case .rereading: return "Rereading"
        }
    }
}
