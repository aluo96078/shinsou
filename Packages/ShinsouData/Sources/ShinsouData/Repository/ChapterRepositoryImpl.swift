import Foundation
import GRDB
import ShinsouDomain

public final class ChapterRepositoryImpl: ChapterRepository {
    private let dbPool: DatabasePool

    public init(databaseManager: DatabaseManager) {
        self.dbPool = databaseManager.dbPool
    }

    // MARK: - Read

    public func getChaptersByMangaId(mangaId: Int64) async throws -> [Chapter] {
        try await dbPool.read { db in
            try ChapterRecord
                .filter(Column("manga_id") == mangaId)
                .order(Column("source_order").desc)
                .fetchAll(db)
                .map { $0.toDomain() }
        }
    }

    public func getChapter(id: Int64) async throws -> Chapter? {
        try await dbPool.read { db in
            try ChapterRecord.fetchOne(db, key: id)?.toDomain()
        }
    }

    public func getChapterByUrl(url: String, mangaId: Int64) async throws -> Chapter? {
        try await dbPool.read { db in
            try ChapterRecord
                .filter(Column("url") == url && Column("manga_id") == mangaId)
                .fetchOne(db)?
                .toDomain()
        }
    }

    // MARK: - Observe

    public func observeChaptersByMangaId(mangaId: Int64) -> AsyncStream<[Chapter]> {
        let observation = ValueObservation.tracking { db in
            try ChapterRecord
                .filter(Column("manga_id") == mangaId)
                .order(Column("source_order").desc)
                .fetchAll(db)
                .map { $0.toDomain() }
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

    public func insert(chapter: Chapter) async throws -> Int64 {
        try await dbPool.write { db in
            var record = ChapterRecord.from(domain: chapter)
            try record.insert(db)
            return db.lastInsertedRowID
        }
    }

    public func insertAll(chapters: [Chapter]) async throws {
        try await dbPool.write { db in
            for chapter in chapters {
                var record = ChapterRecord.from(domain: chapter)
                try record.insert(db)
            }
        }
    }

    public func update(chapter: Chapter) async throws {
        try await dbPool.write { db in
            let record = ChapterRecord.from(domain: chapter)
            try record.update(db)
        }
    }

    public func updatePartial(id: Int64, read: Bool?, bookmark: Bool?, lastPageRead: Int?) async throws {
        try await dbPool.write { db in
            guard var record = try ChapterRecord.fetchOne(db, key: id) else { return }
            if let read = read { record.read = read ? 1 : 0 }
            if let bookmark = bookmark { record.bookmark = bookmark ? 1 : 0 }
            if let lastPageRead = lastPageRead { record.lastPageRead = lastPageRead }
            try record.update(db)
        }
    }

    public func delete(chapterIds: [Int64]) async throws {
        try await dbPool.write { db in
            _ = try ChapterRecord.deleteAll(db, keys: chapterIds)
        }
    }
}
