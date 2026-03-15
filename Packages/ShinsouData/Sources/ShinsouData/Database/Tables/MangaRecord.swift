import Foundation
import GRDB
import ShinsouDomain

public struct MangaRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    public static let databaseTableName = "manga"

    public var id: Int64?
    public var source: Int64
    public var url: String
    public var title: String
    public var artist: String?
    public var author: String?
    public var description: String?
    public var genre: String? // JSON array
    public var status: Int64
    public var thumbnailUrl: String?
    public var favorite: Bool
    public var lastUpdate: Int64
    public var nextUpdate: Int64
    public var fetchInterval: Int
    public var dateAdded: Int64
    public var viewerFlags: Int64
    public var chapterFlags: Int64
    public var coverLastModified: Int64
    public var updateStrategy: Int
    public var initialized: Bool
    public var lastModifiedAt: Int64
    public var favoriteModifiedAt: Int64?
    public var version: Int64
    public var notes: String

    enum CodingKeys: String, CodingKey {
        case id, source, url, title, artist, author, description, genre, status
        case thumbnailUrl = "thumbnail_url"
        case favorite
        case lastUpdate = "last_update"
        case nextUpdate = "next_update"
        case fetchInterval = "fetch_interval"
        case dateAdded = "date_added"
        case viewerFlags = "viewer_flags"
        case chapterFlags = "chapter_flags"
        case coverLastModified = "cover_last_modified"
        case updateStrategy = "update_strategy"
        case initialized
        case lastModifiedAt = "last_modified_at"
        case favoriteModifiedAt = "favorite_modified_at"
        case version, notes
    }

    public func toDomain() -> Manga {
        let genreList: [String]? = genre.flatMap {
            try? JSONDecoder().decode([String].self, from: Data($0.utf8))
        }
        return Manga(
            id: id ?? -1, source: source, favorite: favorite,
            lastUpdate: lastUpdate, nextUpdate: nextUpdate,
            fetchInterval: fetchInterval, dateAdded: dateAdded,
            viewerFlags: viewerFlags, chapterFlags: chapterFlags,
            coverLastModified: coverLastModified, url: url,
            title: title, artist: artist, author: author,
            description: description, genre: genreList, status: status,
            thumbnailUrl: thumbnailUrl, updateStrategy: updateStrategy,
            initialized: initialized, lastModifiedAt: lastModifiedAt,
            favoriteModifiedAt: favoriteModifiedAt, version: version,
            notes: notes
        )
    }

    public static func from(domain: Manga) -> MangaRecord {
        let genreJson: String? = domain.genre.flatMap {
            guard let data = try? JSONEncoder().encode($0) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        return MangaRecord(
            id: domain.id == -1 ? nil : domain.id,
            source: domain.source, url: domain.url, title: domain.title,
            artist: domain.artist, author: domain.author,
            description: domain.description, genre: genreJson,
            status: domain.status, thumbnailUrl: domain.thumbnailUrl,
            favorite: domain.favorite, lastUpdate: domain.lastUpdate,
            nextUpdate: domain.nextUpdate, fetchInterval: domain.fetchInterval,
            dateAdded: domain.dateAdded, viewerFlags: domain.viewerFlags,
            chapterFlags: domain.chapterFlags,
            coverLastModified: domain.coverLastModified,
            updateStrategy: domain.updateStrategy,
            initialized: domain.initialized,
            lastModifiedAt: domain.lastModifiedAt,
            favoriteModifiedAt: domain.favoriteModifiedAt,
            version: domain.version, notes: domain.notes
        )
    }
}
