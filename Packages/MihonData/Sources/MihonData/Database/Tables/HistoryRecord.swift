import Foundation
import GRDB
import MihonDomain

public struct HistoryRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "history"

    public var id: Int64?
    public var chapterId: Int64  // unique
    public var lastRead: Int64
    public var timeRead: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case chapterId = "chapter_id"
        case lastRead = "last_read"
        case timeRead = "time_read"
    }

    public func toDomain() -> History {
        History(
            id: id ?? -1,
            chapterId: chapterId,
            lastRead: lastRead,
            timeRead: timeRead
        )
    }

    public static func from(domain: History) -> HistoryRecord {
        HistoryRecord(
            id: domain.id == -1 ? nil : domain.id,
            chapterId: domain.chapterId,
            lastRead: domain.lastRead,
            timeRead: domain.timeRead
        )
    }
}
