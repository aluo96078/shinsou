import Foundation

public struct History: Sendable, Equatable {
    public let id: Int64
    public let chapterId: Int64
    public let lastRead: Int64
    public let timeRead: Int64

    public init(id: Int64 = -1, chapterId: Int64, lastRead: Int64 = 0, timeRead: Int64 = 0) {
        self.id = id
        self.chapterId = chapterId
        self.lastRead = lastRead
        self.timeRead = timeRead
    }
}
