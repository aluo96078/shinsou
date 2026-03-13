import Foundation
import MihonDomain

// MARK: - TrackerState

struct TrackerState: Identifiable {
    var id: Int { tracker.id }
    let tracker: any Tracker
    var track: Track?
}

// MARK: - IdentifiableTracker

/// Wraps `any Tracker` to satisfy `Identifiable` requirements for `.sheet(item:)`.
struct IdentifiableTracker: Identifiable {
    let id: Int
    let tracker: any Tracker

    init(tracker: any Tracker) {
        self.id = tracker.id
        self.tracker = tracker
    }
}

// MARK: - TrackSheetViewModel

@MainActor
final class TrackSheetViewModel: ObservableObject {

    let mangaId: Int64

    @Published var trackerStates: [TrackerState] = []
    @Published var searchingTracker: IdentifiableTracker? = nil
    @Published var loginTracker: IdentifiableTracker? = nil
    @Published var error: String? = nil

    private let trackRepository: TrackRepository

    init(mangaId: Int64) {
        self.mangaId = mangaId
        self.trackRepository = DIContainer.shared.trackRepository
    }

    // MARK: - Load

    func loadTracks() async {
        let allTrackers = TrackerManager.shared.trackers

        do {
            let existingTracks = try await trackRepository.getTracksByMangaId(mangaId: mangaId)
            let trackByTrackerId = Dictionary(uniqueKeysWithValues: existingTracks.map { ($0.trackerId, $0) })

            trackerStates = allTrackers.map { tracker in
                TrackerState(tracker: tracker, track: trackByTrackerId[tracker.id])
            }
        } catch {
            self.error = error.localizedDescription
            // Still show all trackers even if DB lookup fails.
            trackerStates = allTrackers.map { TrackerState(tracker: $0, track: nil) }
        }
    }

    // MARK: - Binding

    func showSearch(for tracker: any Tracker) {
        guard tracker.isLoggedIn else {
            loginTracker = IdentifiableTracker(tracker: tracker)
            return
        }
        searchingTracker = IdentifiableTracker(tracker: tracker)
    }

    func bind(tracker: any Tracker, search: TrackSearch) async {
        var newTrack = Track(
            mangaId: mangaId,
            trackerId: tracker.id,
            remoteId: search.id,
            title: search.title,
            totalChapters: search.totalChapters
        )

        do {
            newTrack = try await tracker.bind(track: newTrack, remoteSearch: search)
            let insertedId = try await trackRepository.insert(track: newTrack)
            newTrack = Track(
                id: insertedId,
                mangaId: newTrack.mangaId,
                trackerId: newTrack.trackerId,
                remoteId: newTrack.remoteId,
                title: newTrack.title,
                lastChapterRead: newTrack.lastChapterRead,
                totalChapters: newTrack.totalChapters,
                status: newTrack.status,
                score: newTrack.score,
                remoteUrl: newTrack.remoteUrl,
                startDate: newTrack.startDate,
                finishDate: newTrack.finishDate
            )
            updateState(trackerId: tracker.id, track: newTrack)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Remove

    func removeTrack(tracker: any Tracker) async {
        do {
            try await trackRepository.delete(mangaId: mangaId, trackerId: tracker.id)
            updateState(trackerId: tracker.id, track: nil)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Update Status / Score / Chapter

    func updateStatus(tracker: any Tracker, status: TrackStatus) async {
        guard var track = currentTrack(for: tracker) else { return }
        track = Track(
            id: track.id, mangaId: track.mangaId, trackerId: track.trackerId,
            remoteId: track.remoteId, title: track.title,
            lastChapterRead: track.lastChapterRead, totalChapters: track.totalChapters,
            status: status.rawValue, score: track.score,
            remoteUrl: track.remoteUrl, startDate: track.startDate, finishDate: track.finishDate
        )
        await pushUpdate(tracker: tracker, track: track)
    }

    func updateScore(tracker: any Tracker, score: Double) async {
        guard var track = currentTrack(for: tracker) else { return }
        track = Track(
            id: track.id, mangaId: track.mangaId, trackerId: track.trackerId,
            remoteId: track.remoteId, title: track.title,
            lastChapterRead: track.lastChapterRead, totalChapters: track.totalChapters,
            status: track.status, score: score,
            remoteUrl: track.remoteUrl, startDate: track.startDate, finishDate: track.finishDate
        )
        await pushUpdate(tracker: tracker, track: track)
    }

    func updateChapter(tracker: any Tracker, chapter: Double) async {
        guard var track = currentTrack(for: tracker) else { return }
        track = Track(
            id: track.id, mangaId: track.mangaId, trackerId: track.trackerId,
            remoteId: track.remoteId, title: track.title,
            lastChapterRead: chapter, totalChapters: track.totalChapters,
            status: track.status, score: track.score,
            remoteUrl: track.remoteUrl, startDate: track.startDate, finishDate: track.finishDate
        )
        await pushUpdate(tracker: tracker, track: track)
    }

    // MARK: - Private Helpers

    private func currentTrack(for tracker: any Tracker) -> Track? {
        trackerStates.first { $0.tracker.id == tracker.id }?.track
    }

    private func pushUpdate(tracker: any Tracker, track: Track) async {
        do {
            let updated = try await tracker.update(track: track)
            try await trackRepository.update(track: updated)
            updateState(trackerId: tracker.id, track: updated)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func updateState(trackerId: Int, track: Track?) {
        if let idx = trackerStates.firstIndex(where: { $0.tracker.id == trackerId }) {
            trackerStates[idx].track = track
        }
    }
}
