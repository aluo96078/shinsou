import Foundation
import GRDB
import ShinsouDomain

public final class UpdatesRepositoryImpl: UpdatesRepository {
    private let dbPool: DatabasePool

    public init(databaseManager: DatabaseManager) {
        self.dbPool = databaseManager.dbPool
    }

    // MARK: - Read

    public func getRecentUpdates(limit: Int) async throws -> [UpdateItem] {
        try await dbPool.read { db in
            try Self.fetchRecentUpdates(db, limit: limit)
        }
    }

    // MARK: - Observe

    public func observeRecentUpdates(limit: Int) -> AsyncStream<[UpdateItem]> {
        let observation = ValueObservation.tracking { db in
            try Self.fetchRecentUpdates(db, limit: limit)
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

    // MARK: - Private Helpers

    private static func fetchRecentUpdates(_ db: Database, limit: Int) throws -> [UpdateItem] {
        let sql = """
            SELECT manga.*, chapter.*
            FROM chapter
            INNER JOIN manga ON manga.id = chapter.manga_id
            WHERE manga.favorite = 1
            ORDER BY chapter.date_fetch DESC
            LIMIT ?
            """

        struct UpdateRow: FetchableRecord {
            let manga: MangaRecord
            let chapter: ChapterRecord

            init(row: GRDB.Row) throws {
                manga = try MangaRecord(row: row)
                chapter = try ChapterRecord(row: row)
            }
        }

        let rows = try UpdateRow.fetchAll(db, sql: sql, arguments: [limit])
        return rows.map { row in
            UpdateItem(
                manga: row.manga.toDomain(),
                chapter: row.chapter.toDomain()
            )
        }
    }
}
