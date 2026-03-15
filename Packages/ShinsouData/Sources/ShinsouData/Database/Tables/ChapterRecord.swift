import Foundation
import GRDB
import ShinsouDomain

public struct ChapterRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "chapter"

    public var id: Int64?
    public var mangaId: Int64
    public var url: String
    public var name: String
    public var scanlator: String?
    public var read: Int       // Bool stored as Int
    public var bookmark: Int   // Bool stored as Int
    public var lastPageRead: Int
    public var chapterNumber: Double
    public var sourceOrder: Int
    public var dateFetch: Int64
    public var dateUpload: Int64
    public var lastModifiedAt: Int64
    public var version: Int64

    enum CodingKeys: String, CodingKey {
        case id
        case mangaId = "manga_id"
        case url, name, scanlator, read, bookmark
        case lastPageRead = "last_page_read"
        case chapterNumber = "chapter_number"
        case sourceOrder = "source_order"
        case dateFetch = "date_fetch"
        case dateUpload = "date_upload"
        case lastModifiedAt = "last_modified_at"
        case version
    }

    public func toDomain() -> Chapter {
        Chapter(
            id: id ?? -1,
            mangaId: mangaId,
            url: url,
            name: name,
            scanlator: scanlator,
            read: read != 0,
            bookmark: bookmark != 0,
            lastPageRead: lastPageRead,
            chapterNumber: chapterNumber,
            sourceOrder: sourceOrder,
            dateFetch: dateFetch,
            dateUpload: dateUpload,
            lastModifiedAt: lastModifiedAt,
            version: version
        )
    }

    public static func from(domain: Chapter) -> ChapterRecord {
        ChapterRecord(
            id: domain.id == -1 ? nil : domain.id,
            mangaId: domain.mangaId,
            url: domain.url,
            name: domain.name,
            scanlator: domain.scanlator,
            read: domain.read ? 1 : 0,
            bookmark: domain.bookmark ? 1 : 0,
            lastPageRead: domain.lastPageRead,
            chapterNumber: domain.chapterNumber,
            sourceOrder: domain.sourceOrder,
            dateFetch: domain.dateFetch,
            dateUpload: domain.dateUpload,
            lastModifiedAt: domain.lastModifiedAt,
            version: domain.version
        )
    }
}
