import Foundation
import GRDB
import ShinsouDomain

public final class MangaRepositoryImpl: MangaRepository {
    private let dbPool: DatabasePool

    public init(databaseManager: DatabaseManager) {
        self.dbPool = databaseManager.dbPool
    }

    // MARK: - Read

    public func getManga(id: Int64) async throws -> Manga? {
        try await dbPool.read { db in
            try MangaRecord.fetchOne(db, key: id)?.toDomain()
        }
    }

    public func getMangaByUrlAndSource(url: String, sourceId: Int64) async throws -> Manga? {
        try await dbPool.read { db in
            try MangaRecord
                .filter(Column("url") == url && Column("source") == sourceId)
                .fetchOne(db)?
                .toDomain()
        }
    }

    public func getFavorites() async throws -> [Manga] {
        try await dbPool.read { db in
            try MangaRecord
                .filter(Column("favorite") == true)
                .fetchAll(db)
                .map { $0.toDomain() }
        }
    }

    public func getLibraryManga() async throws -> [LibraryManga] {
        try await dbPool.read { db in
            try Self.fetchLibraryManga(db)
        }
    }

    // MARK: - Observe

    public func observeLibraryManga() -> AsyncStream<[LibraryManga]> {
        let observation = ValueObservation.tracking { db in
            try Self.fetchLibraryManga(db)
        }
        return AsyncStream { continuation in
            let cancellable = observation.start(
                in: dbPool,
                scheduling: .async(onQueue: .global()),
                onError: { _ in continuation.finish() },
                onChange: { value in continuation.yield(value) }
            )
            continuation.onTermination = { _ in cancellable.cancel() }
        }
    }

    public func observeManga(id: Int64) -> AsyncStream<Manga?> {
        let observation = ValueObservation.tracking { db in
            try MangaRecord.fetchOne(db, key: id)?.toDomain()
        }
        return AsyncStream { continuation in
            let cancellable = observation.start(
                in: dbPool,
                scheduling: .async(onQueue: .global()),
                onError: { _ in continuation.finish() },
                onChange: { value in continuation.yield(value) }
            )
            continuation.onTermination = { _ in cancellable.cancel() }
        }
    }

    // MARK: - Write

    public func insert(manga: Manga) async throws -> Int64 {
        try await dbPool.write { db in
            var record = MangaRecord.from(domain: manga)
            try record.insert(db)
            return db.lastInsertedRowID
        }
    }

    public func update(manga: Manga) async throws {
        try await dbPool.write { db in
            let record = MangaRecord.from(domain: manga)
            try record.update(db)
        }
    }

    public func updatePartial(id: Int64, updates: MangaUpdate) async throws {
        try await dbPool.write { db in
            guard var record = try MangaRecord.fetchOne(db, key: id) else { return }
            if let favorite = updates.favorite { record.favorite = favorite }
            if let title = updates.title { record.title = title }
            if let author = updates.author { record.author = author }
            if let artist = updates.artist { record.artist = artist }
            if let description = updates.description { record.description = description }
            if let genre = updates.genre {
                if let data = try? JSONEncoder().encode(genre) {
                    record.genre = String(data: data, encoding: .utf8)
                }
            }
            if let status = updates.status { record.status = status }
            if let chapterFlags = updates.chapterFlags { record.chapterFlags = chapterFlags }
            if let viewerFlags = updates.viewerFlags { record.viewerFlags = viewerFlags }
            if let notes = updates.notes { record.notes = notes }
            if let dateAdded = updates.dateAdded { record.dateAdded = dateAdded }
            if let thumbnailUrl = updates.thumbnailUrl { record.thumbnailUrl = thumbnailUrl }
            if let initialized = updates.initialized { record.initialized = initialized }
            try record.update(db)
        }
    }

    public func delete(mangaId: Int64) async throws {
        try await dbPool.write { db in
            _ = try MangaRecord.deleteOne(db, key: mangaId)
        }
    }

    // MARK: - Private Helpers

    private static func fetchLibraryManga(_ db: Database) throws -> [LibraryManga] {
        let sql = """
            SELECT
                manga.*,
                COUNT(chapter.id) AS total_chapters,
                SUM(chapter.read) AS read_count,
                SUM(chapter.bookmark) AS bookmark_count,
                MAX(chapter.date_upload) AS latest_upload,
                MAX(chapter.date_fetch) AS chapter_fetched_at,
                COALESCE(MAX(history.last_read), 0) AS last_read,
                COALESCE(manga_category.category_id, 0) AS category
            FROM manga
            LEFT JOIN chapter ON chapter.manga_id = manga.id
            LEFT JOIN history ON history.chapter_id = chapter.id
            LEFT JOIN manga_category ON manga_category.manga_id = manga.id
            WHERE manga.favorite = 1
            GROUP BY manga.id, COALESCE(manga_category.category_id, 0)
            """

        struct Row: FetchableRecord {
            let manga: MangaRecord
            let totalChapters: Int
            let readCount: Int
            let bookmarkCount: Int
            let latestUpload: Int64
            let chapterFetchedAt: Int64
            let lastRead: Int64
            let category: Int64

            init(row: GRDB.Row) throws {
                manga = try MangaRecord(row: row)
                totalChapters = row["total_chapters"] ?? 0
                readCount = row["read_count"] ?? 0
                bookmarkCount = row["bookmark_count"] ?? 0
                latestUpload = row["latest_upload"] ?? 0
                chapterFetchedAt = row["chapter_fetched_at"] ?? 0
                lastRead = row["last_read"] ?? 0
                category = row["category"] ?? 0
            }
        }

        let rows = try Row.fetchAll(db, sql: sql)
        return rows.map { row in
            LibraryManga(
                manga: row.manga.toDomain(),
                totalChapters: row.totalChapters,
                readCount: row.readCount,
                bookmarkCount: row.bookmarkCount,
                latestUpload: row.latestUpload,
                chapterFetchedAt: row.chapterFetchedAt,
                lastRead: row.lastRead,
                category: row.category
            )
        }
    }
}
