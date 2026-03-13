import Foundation
import GRDB
import MihonDomain

public final class CategoryRepositoryImpl: CategoryRepository {
    private let dbPool: DatabasePool

    public init(databaseManager: DatabaseManager) {
        self.dbPool = databaseManager.dbPool
    }

    // MARK: - Read

    public func getAll() async throws -> [MihonDomain.Category] {
        try await dbPool.read { db in
            try CategoryRecord
                .order(Column("sort").asc)
                .fetchAll(db)
                .map { $0.toDomain() }
        }
    }

    public func getCategoriesForManga(mangaId: Int64) async throws -> [MihonDomain.Category] {
        try await dbPool.read { db in
            let sql = """
                SELECT category.*
                FROM category
                INNER JOIN manga_category ON manga_category.category_id = category.id
                WHERE manga_category.manga_id = ?
                ORDER BY category.sort ASC
                """
            return try CategoryRecord.fetchAll(db, sql: sql, arguments: [mangaId])
                .map { $0.toDomain() }
        }
    }

    // MARK: - Observe

    public func observeAll() -> AsyncStream<[MihonDomain.Category]> {
        let observation = ValueObservation.tracking { db in
            try CategoryRecord
                .order(Column("sort").asc)
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

    public func insert(category: MihonDomain.Category) async throws -> Int64 {
        try await dbPool.write { db in
            var record = CategoryRecord.from(domain: category)
            try record.insert(db)
            return db.lastInsertedRowID
        }
    }

    public func update(category: MihonDomain.Category) async throws {
        try await dbPool.write { db in
            let record = CategoryRecord.from(domain: category)
            try record.update(db)
        }
    }

    public func delete(categoryId: Int64) async throws {
        try await dbPool.write { db in
            _ = try CategoryRecord.deleteOne(db, key: categoryId)
        }
    }

    public func setMangaCategories(mangaId: Int64, categoryIds: [Int64]) async throws {
        try await dbPool.write { db in
            // 刪除該漫畫所有舊的分類關聯
            try MangaCategoryRecord
                .filter(Column("manga_id") == mangaId)
                .deleteAll(db)
            // 插入新的分類關聯
            for categoryId in categoryIds {
                let record = MangaCategoryRecord(mangaId: mangaId, categoryId: categoryId)
                try record.insert(db)
            }
        }
    }
}
