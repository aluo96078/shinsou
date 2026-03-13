import Foundation
import GRDB
import MihonDomain

public final class ExtensionRepoRepositoryImpl: ExtensionRepoRepository {
    private let dbPool: DatabasePool

    public init(databaseManager: DatabaseManager) {
        self.dbPool = databaseManager.dbPool
    }

    // MARK: - Read

    public func getAll() async throws -> [ExtensionRepo] {
        try await dbPool.read { db in
            try ExtensionRepoRecord
                .order(Column("name").asc)
                .fetchAll(db)
                .map { $0.toDomain() }
        }
    }

    public func getRepo(baseUrl: String) async throws -> ExtensionRepo? {
        try await dbPool.read { db in
            try ExtensionRepoRecord.fetchOne(db, key: baseUrl)?.toDomain()
        }
    }

    public func getCount() async throws -> Int {
        try await dbPool.read { db in
            try ExtensionRepoRecord.fetchCount(db)
        }
    }

    // MARK: - Observe

    public func observeAll() -> AsyncStream<[ExtensionRepo]> {
        let observation = ValueObservation.tracking { db in
            try ExtensionRepoRecord
                .order(Column("name").asc)
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

    public func insert(repo: ExtensionRepo) async throws {
        try await dbPool.write { db in
            let record = ExtensionRepoRecord.from(domain: repo)
            try record.insert(db)
        }
    }

    public func update(repo: ExtensionRepo) async throws {
        try await dbPool.write { db in
            let record = ExtensionRepoRecord.from(domain: repo)
            try record.update(db)
        }
    }

    public func delete(baseUrl: String) async throws {
        try await dbPool.write { db in
            _ = try ExtensionRepoRecord.deleteOne(db, key: baseUrl)
        }
    }
}
