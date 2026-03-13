import Foundation
import SwiftUI
import MihonDomain
import MihonSourceAPI

// MARK: - MigrationSourcesViewModel

/// Loads all sources that have at least one favourite manga in the library,
/// grouped and sorted by the count of manga per source (descending).
@MainActor
final class MigrationSourcesViewModel: ObservableObject {
    @Published var sources: [MigrationSource] = []
    @Published var isLoading = false

    private let mangaRepo: MangaRepository = DIContainer.shared.mangaRepository

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let library = try await mangaRepo.getFavorites()

            // Group by source ID.
            var counts: [Int64: Int] = [:]
            for manga in library {
                counts[manga.source, default: 0] += 1
            }

            // Resolve human-readable source names.
            let sourceManager = SourceManager.shared
            var result: [MigrationSource] = counts.compactMap { (sourceId, count) in
                let name = sourceManager.getSource(id: sourceId)?.name ?? "Unknown (\(sourceId))"
                return MigrationSource(id: sourceId, name: name, mangaCount: count)
            }

            // Sort descending by manga count, then alphabetically.
            result.sort {
                if $0.mangaCount != $1.mangaCount { return $0.mangaCount > $1.mangaCount }
                return $0.name < $1.name
            }

            sources = result
        } catch {
            print("[MigrationSourcesViewModel] Failed to load library: \(error)")
        }
    }
}

// MARK: - MigrationMangaListViewModel

/// Loads all favourite manga belonging to a specific source.
@MainActor
final class MigrationMangaListViewModel: ObservableObject {
    @Published var mangas: [Manga] = []
    @Published var isLoading = false

    private let sourceId: Int64
    private let mangaRepo: MangaRepository = DIContainer.shared.mangaRepository

    init(sourceId: Int64) {
        self.sourceId = sourceId
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let all = try await mangaRepo.getFavorites()
            mangas = all
                .filter { $0.source == sourceId }
                .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        } catch {
            print("[MigrationMangaListViewModel] Failed to load manga: \(error)")
        }
    }
}

// MARK: - MigrationSearchGroup

/// Represents the smart-search results from a single source.
struct MigrationSearchGroup: Identifiable {
    let id: Int64          // source ID
    let sourceId: Int64
    let sourceName: String
    var results: [SManga] = []
    var isLoading: Bool = true
    var error: String?
}

// MARK: - MigrationSearchViewModel

/// Drives the smart-search UI and executes the migration.
@MainActor
final class MigrationSearchViewModel: ObservableObject {
    // MARK: Search state
    @Published var results: [MigrationSearchGroup] = []
    @Published var isSearching = false

    // MARK: Migration state
    @Published var isMigrating = false
    @Published var migrationSuccess = false
    @Published var migrationError: String?

    private let manga: Manga
    private let engine = SmartSearchEngine()

    private let mangaRepo: MangaRepository      = DIContainer.shared.mangaRepository
    private let chapterRepo: ChapterRepository  = DIContainer.shared.chapterRepository
    private let categoryRepo: CategoryRepository = DIContainer.shared.categoryRepository
    private let trackRepo: TrackRepository      = DIContainer.shared.trackRepository

    init(manga: Manga) {
        self.manga = manga
    }

    // MARK: - Smart Search

    func smartSearch() async {
        isSearching = true
        defer { isSearching = false }

        let sources = SourceManager.shared.catalogueSources
        // Initialise all groups as loading.
        results = sources.map {
            MigrationSearchGroup(id: $0.id, sourceId: $0.id, sourceName: $0.name)
        }

        let searchResults = await engine.smartSearch(title: manga.title, sources: sources)

        // Map results back to groups (preserve order returned by engine).
        results = searchResults.map { pair in
            MigrationSearchGroup(
                id: pair.source.id,
                sourceId: pair.source.id,
                sourceName: pair.source.name,
                results: pair.results,
                isLoading: false,
                error: nil
            )
        }
    }

    // MARK: - Migration

    /// Migrates `manga` (old) to `newManga` on `sourceId`.
    ///
    /// Steps:
    /// 1. Upsert the new manga record in the database.
    /// 2. Copy chapter read status by matching `chapterNumber`.
    /// 3. Copy categories from the old manga to the new manga.
    /// 4. Copy tracks (re-linked to new manga ID, title updated).
    /// 5. Remove the old manga from the library (unfavourite).
    func migrate(to newManga: SManga, sourceId: Int64) async {
        isMigrating = true
        defer { isMigrating = false }

        do {
            // ----------------------------------------------------------------
            // Step 1 – Upsert new manga record.
            // ----------------------------------------------------------------
            let now = Int64(Date().timeIntervalSince1970 * 1000)

            // Fetch existing record if the user previously visited this manga
            // on the target source.
            var newMangaId: Int64
            if let existing = try await mangaRepo.getMangaByUrlAndSource(
                url: newManga.url,
                sourceId: sourceId
            ) {
                newMangaId = existing.id
                // Ensure it is marked as favourite.
                try await mangaRepo.updatePartial(
                    id: newMangaId,
                    updates: MangaUpdate(favorite: true, dateAdded: now)
                )
            } else {
                let record = buildMangaRecord(from: newManga, sourceId: sourceId, now: now)
                newMangaId = try await mangaRepo.insert(manga: record)
            }

            // ----------------------------------------------------------------
            // Step 2 – Copy chapter read status.
            // ----------------------------------------------------------------
            let oldChapters = try await chapterRepo.getChaptersByMangaId(mangaId: manga.id)
            let newChapters = try await chapterRepo.getChaptersByMangaId(mangaId: newMangaId)

            // Build a lookup: chapter number -> read/bookmark/lastPageRead from old manga.
            struct ReadState { let read: Bool; let bookmark: Bool; let lastPageRead: Int }
            var readMap: [Double: ReadState] = [:]
            for ch in oldChapters where ch.read || ch.bookmark || ch.lastPageRead > 0 {
                readMap[ch.chapterNumber] = ReadState(
                    read: ch.read,
                    bookmark: ch.bookmark,
                    lastPageRead: ch.lastPageRead
                )
            }

            for newCh in newChapters {
                if let state = readMap[newCh.chapterNumber] {
                    try await chapterRepo.updatePartial(
                        id: newCh.id,
                        read: state.read,
                        bookmark: state.bookmark,
                        lastPageRead: state.lastPageRead
                    )
                }
            }

            // ----------------------------------------------------------------
            // Step 3 – Copy categories.
            // ----------------------------------------------------------------
            let categories = try await categoryRepo.getCategoriesForManga(mangaId: manga.id)
            if !categories.isEmpty {
                let categoryIds = categories.map(\.id)
                try await categoryRepo.setMangaCategories(mangaId: newMangaId, categoryIds: categoryIds)
            }

            // ----------------------------------------------------------------
            // Step 4 – Copy tracks (update mangaId and title on new record).
            // ----------------------------------------------------------------
            let tracks = try await trackRepo.getTracksByMangaId(mangaId: manga.id)
            for track in tracks {
                // Check if there is already a track for the same tracker on the new manga.
                let existingNewTracks = try await trackRepo.getTracksByMangaId(mangaId: newMangaId)
                if existingNewTracks.contains(where: { $0.trackerId == track.trackerId }) {
                    continue // Don't duplicate tracker entries.
                }
                let migratedTrack = Track(
                    id: -1,                          // let DB assign new ID
                    mangaId: newMangaId,
                    trackerId: track.trackerId,
                    remoteId: track.remoteId,
                    title: newManga.title,           // update to new manga title
                    lastChapterRead: track.lastChapterRead,
                    totalChapters: track.totalChapters,
                    status: track.status,
                    score: track.score,
                    remoteUrl: track.remoteUrl,
                    startDate: track.startDate,
                    finishDate: track.finishDate
                )
                _ = try await trackRepo.insert(track: migratedTrack)
            }

            // ----------------------------------------------------------------
            // Step 5 – Remove old manga from library (unfavourite).
            // ----------------------------------------------------------------
            try await mangaRepo.updatePartial(
                id: manga.id,
                updates: MangaUpdate(favorite: false)
            )

            migrationSuccess = true
        } catch {
            migrationError = error.localizedDescription
            print("[MigrationSearchViewModel] Migration failed: \(error)")
        }
    }

    // MARK: - Helpers

    private func buildMangaRecord(from smanga: SManga, sourceId: Int64, now: Int64) -> Manga {
        Manga(
            id: -1,
            source: sourceId,
            favorite: true,
            lastUpdate: 0,
            nextUpdate: 0,
            fetchInterval: 0,
            dateAdded: now,
            viewerFlags: manga.viewerFlags,
            chapterFlags: manga.chapterFlags,
            coverLastModified: 0,
            url: smanga.url,
            title: smanga.title,
            artist: smanga.artist,
            author: smanga.author,
            description: smanga.description,
            genre: smanga.genre,
            status: Int64(smanga.status.rawValue),
            thumbnailUrl: smanga.thumbnailUrl,
            updateStrategy: smanga.updateStrategy.rawValue,
            initialized: smanga.initialized,
            lastModifiedAt: now,
            favoriteModifiedAt: now,
            version: 1,
            notes: manga.notes
        )
    }
}
