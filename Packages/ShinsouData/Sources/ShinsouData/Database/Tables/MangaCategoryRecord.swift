import Foundation
import GRDB

public struct MangaCategoryRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "manga_category"

    public var mangaId: Int64
    public var categoryId: Int64

    enum CodingKeys: String, CodingKey {
        case mangaId = "manga_id"
        case categoryId = "category_id"
    }

    public init(mangaId: Int64, categoryId: Int64) {
        self.mangaId = mangaId
        self.categoryId = categoryId
    }
}
