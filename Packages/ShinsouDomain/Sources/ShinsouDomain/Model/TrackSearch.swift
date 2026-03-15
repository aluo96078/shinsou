import Foundation

public struct TrackSearch: Identifiable, Sendable, Equatable {
    public let id: Int64  // remote id
    public var title: String
    public var totalChapters: Int
    public var coverUrl: String
    public var summary: String
    public var publishingStatus: String
    public var publishingType: String
    public var startDate: String

    public init(id: Int64, title: String, totalChapters: Int = 0, coverUrl: String = "", summary: String = "", publishingStatus: String = "", publishingType: String = "", startDate: String = "") {
        self.id = id
        self.title = title
        self.totalChapters = totalChapters
        self.coverUrl = coverUrl
        self.summary = summary
        self.publishingStatus = publishingStatus
        self.publishingType = publishingType
        self.startDate = startDate
    }
}
