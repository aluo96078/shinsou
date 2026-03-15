import Foundation
import GRDB
import ShinsouDomain

public struct TrackRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "track"

    public var id: Int64?
    public var mangaId: Int64
    public var trackerId: Int
    public var remoteId: Int64
    public var title: String
    public var lastChapterRead: Double
    public var totalChapters: Int
    public var status: Int
    public var score: Double
    public var remoteUrl: String
    public var startDate: Int64
    public var finishDate: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case mangaId = "manga_id"
        case trackerId = "tracker_id"
        case remoteId = "remote_id"
        case title
        case lastChapterRead = "last_chapter_read"
        case totalChapters = "total_chapters"
        case status, score
        case remoteUrl = "remote_url"
        case startDate = "start_date"
        case finishDate = "finish_date"
    }

    public func toDomain() -> Track {
        Track(
            id: id ?? -1,
            mangaId: mangaId,
            trackerId: trackerId,
            remoteId: remoteId,
            title: title,
            lastChapterRead: lastChapterRead,
            totalChapters: totalChapters,
            status: status,
            score: score,
            remoteUrl: remoteUrl,
            startDate: startDate,
            finishDate: finishDate
        )
    }

    public static func from(domain: Track) -> TrackRecord {
        TrackRecord(
            id: domain.id == -1 ? nil : domain.id,
            mangaId: domain.mangaId,
            trackerId: domain.trackerId,
            remoteId: domain.remoteId,
            title: domain.title,
            lastChapterRead: domain.lastChapterRead,
            totalChapters: domain.totalChapters,
            status: domain.status,
            score: domain.score,
            remoteUrl: domain.remoteUrl,
            startDate: domain.startDate,
            finishDate: domain.finishDate
        )
    }
}
