import Foundation
import GRDB
import ShinsouDomain

public final class TrackRepositoryImpl: TrackRepository {
    private let dbPool: DatabasePool

    public init(databaseManager: DatabaseManager) {
        self.dbPool = databaseManager.dbPool
    }

    // MARK: - Read

    public func getTracksByMangaId(mangaId: Int64) async throws -> [Track] {
        try await dbPool.read { db in
            try TrackRecord
                .filter(Column("manga_id") == mangaId)
                .fetchAll(db)
                .map { $0.toDomain() }
        }
    }

    // MARK: - Observe

    public func observeTracksByMangaId(mangaId: Int64) -> AsyncStream<[Track]> {
        let observation = ValueObservation.tracking { db in
            try TrackRecord
                .filter(Column("manga_id") == mangaId)
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

    public func insert(track: Track) async throws -> Int64 {
        try await dbPool.write { db in
            var record = TrackRecord.from(domain: track)
            try record.insert(db)
            return db.lastInsertedRowID
        }
    }

    public func update(track: Track) async throws {
        try await dbPool.write { db in
            let record = TrackRecord.from(domain: track)
            try record.update(db)
        }
    }

    public func delete(mangaId: Int64, trackerId: Int) async throws {
        try await dbPool.write { db in
            try TrackRecord
                .filter(Column("manga_id") == mangaId && Column("tracker_id") == trackerId)
                .deleteAll(db)
        }
    }
}
