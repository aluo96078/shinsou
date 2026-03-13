import Foundation
import GRDB
import MihonDomain

public struct CategoryRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "category"

    public var id: Int64?
    public var name: String
    public var sort: Int
    public var flags: Int64

    enum CodingKeys: String, CodingKey {
        case id, name, sort, flags
    }

    public func toDomain() -> MihonDomain.Category {
        MihonDomain.Category(
            id: id ?? 0,
            name: name,
            sort: sort,
            flags: flags
        )
    }

    public static func from(domain: MihonDomain.Category) -> CategoryRecord {
        CategoryRecord(
            id: domain.id <= 0 ? nil : domain.id,
            name: domain.name,
            sort: domain.sort,
            flags: domain.flags
        )
    }
}
