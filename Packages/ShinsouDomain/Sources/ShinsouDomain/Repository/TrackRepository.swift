import Foundation

public protocol TrackRepository: Sendable {
    func getTracksByMangaId(mangaId: Int64) async throws -> [Track]
    func observeTracksByMangaId(mangaId: Int64) -> AsyncStream<[Track]>
    func insert(track: Track) async throws -> Int64
    func update(track: Track) async throws
    func delete(mangaId: Int64, trackerId: Int) async throws
}
