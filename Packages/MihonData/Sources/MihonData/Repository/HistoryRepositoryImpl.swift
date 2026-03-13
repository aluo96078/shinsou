import Foundation
import GRDB
import MihonDomain

public final class HistoryRepositoryImpl: HistoryRepository {
    private let dbPool: DatabasePool

    public init(databaseManager: DatabaseManager) {
        self.dbPool = databaseManager.dbPool
    }

    // MARK: - Read

    public func getHistory(query: String) async throws -> [HistoryItem] {
        try await dbPool.read { db in
            try Self.fetchHistoryItems(db, query: query)
        }
    }

    // MARK: - Observe

    public func observeHistory(query: String) -> AsyncStream<[HistoryItem]> {
        let observation = ValueObservation.tracking { db in
            try Self.fetchHistoryItems(db, query: query)
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

    public func upsert(chapterId: Int64, readAt: Int64) async throws {
        try await dbPool.write { db in
            if var existing = try HistoryRecord
                .filter(Column("chapter_id") == chapterId)
                .fetchOne(db) {
                existing.lastRead = readAt
                try existing.update(db)
            } else {
                var record = HistoryRecord(
                    id: nil,
                    chapterId: chapterId,
                    lastRead: readAt,
                    timeRead: 0
                )
                try record.insert(db)
            }
        }
    }

    public func deleteByMangaId(mangaId: Int64) async throws {
        try await dbPool.write { db in
            let sql = """
                DELETE FROM history
                WHERE chapter_id IN (
                    SELECT id FROM chapter WHERE manga_id = ?
                )
                """
            try db.execute(sql: sql, arguments: [mangaId])
        }
    }

    public func deleteAll() async throws {
        try await dbPool.write { db in
            try HistoryRecord.deleteAll(db)
        }
    }

    // MARK: - Private Helpers

    private static func fetchHistoryItems(_ db: Database, query: String) throws -> [HistoryItem] {
        let sql: String
        let arguments: StatementArguments

        if query.isEmpty {
            sql = """
                SELECT
                    manga.*,
                    chapter.*,
                    history.last_read
                FROM history
                INNER JOIN chapter ON chapter.id = history.chapter_id
                INNER JOIN manga ON manga.id = chapter.manga_id
                ORDER BY history.last_read DESC
                """
            arguments = []
        } else {
            sql = """
                SELECT
                    manga.*,
                    chapter.*,
                    history.last_read
                FROM history
                INNER JOIN chapter ON chapter.id = history.chapter_id
                INNER JOIN manga ON manga.id = chapter.manga_id
                WHERE manga.title LIKE ?
                ORDER BY history.last_read DESC
                """
            arguments = ["%\(query)%"]
        }

        struct HistoryRow: FetchableRecord {
            let manga: MangaRecord
            let chapter: ChapterRecord
            let lastRead: Int64

            init(row: GRDB.Row) throws {
                manga = try MangaRecord(row: row)
                chapter = try ChapterRecord(row: row)
                lastRead = row["last_read"] ?? 0
            }
        }

        let rows = try HistoryRow.fetchAll(db, sql: sql, arguments: arguments)
        return rows.map { row in
            HistoryItem(
                manga: row.manga.toDomain(),
                chapter: row.chapter.toDomain(),
                lastRead: row.lastRead
            )
        }
    }
}
