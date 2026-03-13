import Foundation

public struct Track: Identifiable, Sendable, Equatable {
    public let id: Int64
    public let mangaId: Int64
    public let trackerId: Int
    public let remoteId: Int64
    public let title: String
    public let lastChapterRead: Double
    public let totalChapters: Int
    public let status: Int
    public let score: Double
    public let remoteUrl: String
    public let startDate: Int64
    public let finishDate: Int64

    public init(
        id: Int64 = -1, mangaId: Int64 = -1, trackerId: Int = 0,
        remoteId: Int64 = 0, title: String = "", lastChapterRead: Double = 0,
        totalChapters: Int = 0, status: Int = 0, score: Double = 0,
        remoteUrl: String = "", startDate: Int64 = 0, finishDate: Int64 = 0
    ) {
        self.id = id; self.mangaId = mangaId; self.trackerId = trackerId
        self.remoteId = remoteId; self.title = title
        self.lastChapterRead = lastChapterRead; self.totalChapters = totalChapters
        self.status = status; self.score = score; self.remoteUrl = remoteUrl
        self.startDate = startDate; self.finishDate = finishDate
    }
}
