import Foundation
import SwiftUI
import Combine
import ShinsouDomain
import ShinsouData

// Explicitly disambiguate LibraryItem from ShinsouDomain (avoids conflict when
// both ShinsouDomain and ShinsouUI are linked to the same target).
typealias LibraryItem = ShinsouDomain.LibraryItem

@MainActor
final class LibraryViewModel: ObservableObject {
    // MARK: - Published State
    @Published var libraryItems: [Int64: [LibraryItem]] = [:] // categoryId -> items
    @Published var categories: [ShinsouDomain.Category] = []
    @Published var selectedCategoryIndex: Int = 0
    @Published var searchQuery: String = ""
    @Published var isLoading: Bool = true
    @Published var selectedMangaIds: Set<Int64> = []
    @Published var isSelectionMode: Bool = false

    // Settings
    @Published var displayMode: LibraryDisplayMode = .compactGrid
    @Published var currentSort: LibrarySort = LibrarySort()
    @Published var currentFilter: LibraryFilter = LibraryFilter()
    @Published var columnsPortrait: Int = 0 // 0 = adaptive
    @Published var columnsLandscape: Int = 0

    // Continue reading
    /// The most recently read manga item across the entire library (nil if nothing has been started).
    @Published var lastReadItem: LibraryItem? = nil

    // MARK: - Dependencies
    private let mangaRepository: MangaRepository
    private let categoryRepository: CategoryRepository
    private let preferences: AppPreferences

    private var observationTask: Task<Void, Never>?
    private var categoryObservationTask: Task<Void, Never>?

    // Cache for latest library manga data
    private var latestLibraryMangas: [LibraryManga] = []

    init(mangaRepository: MangaRepository, categoryRepository: CategoryRepository, preferences: AppPreferences) {
        self.mangaRepository = mangaRepository
        self.categoryRepository = categoryRepository
        self.preferences = preferences

        // Load preferences
        self.displayMode = LibraryDisplayMode(rawValue: preferences.libraryDisplayMode) ?? .compactGrid
        self.columnsPortrait = preferences.libraryColumnsPortrait
        self.columnsLandscape = preferences.libraryColumnsLandscape

        startObserving()
    }

    deinit {
        observationTask?.cancel()
        categoryObservationTask?.cancel()
    }

    // MARK: - Observation

    private var hasSetInitialCategory = false

    private func startObserving() {
        // Observe categories
        categoryObservationTask?.cancel()
        categoryObservationTask = Task { [weak self] in
            guard let self else { return }
            let stream = self.categoryRepository.observeAll()
            for await cats in stream {
                guard !Task.isCancelled else { return }
                let allCategories: [ShinsouDomain.Category] = [ShinsouDomain.Category(id: 0, name: "Default", sort: 0, flags: 0)]
                    + cats.sorted { $0.sort < $1.sort }
                self.categories = allCategories

                // Jump to the user's default category on first load
                if !self.hasSetInitialCategory {
                    self.hasSetInitialCategory = true
                    let defaultCatName = UserDefaults.standard.string(forKey: SettingsKeys.defaultCategory) ?? "Default"
                    if defaultCatName != "Default" && defaultCatName != "__ask__" {
                        if let idx = allCategories.firstIndex(where: { $0.name == defaultCatName }) {
                            self.selectedCategoryIndex = idx
                        }
                    }
                }
            }
        }

        // Observe library manga
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            guard let self else { return }
            let stream = self.mangaRepository.observeLibraryManga()
            for await libraryMangas in stream {
                guard !Task.isCancelled else { return }
                self.latestLibraryMangas = libraryMangas
                self.processLibraryData(libraryMangas)
                self.isLoading = false
            }
        }
    }

    private func processLibraryData(_ libraryMangas: [LibraryManga]) {
        // Determine the most-recently-read manga (unfiltered, across all categories)
        let mostRecent = libraryMangas
            .filter { $0.hasStarted }
            .max { $0.lastRead < $1.lastRead }
        if let lm = mostRecent {
            self.lastReadItem = LibraryItem(
                libraryManga: lm,
                downloadCount: 0,
                isLocal: lm.manga.source == 0,
                sourceLanguage: ""
            )
        } else {
            self.lastReadItem = nil
        }

        // Group by category
        var grouped: [Int64: [LibraryItem]] = [:]

        for lm in libraryMangas {
            let item = LibraryItem(
                libraryManga: lm,
                downloadCount: 0, // TODO: integrate with DownloadManager
                isLocal: lm.manga.source == 0,
                sourceLanguage: ""
            )

            // Apply filters
            if !passesFilter(item) { continue }

            // Apply search
            if !searchQuery.isEmpty && !item.matches(query: searchQuery) { continue }

            let catId = lm.category
            grouped[catId, default: []].append(item)
        }

        // Apply sorting to each category
        for (catId, items) in grouped {
            grouped[catId] = applySorting(to: items)
        }

        self.libraryItems = grouped
    }

    // MARK: - Filtering

    private func passesFilter(_ item: LibraryItem) -> Bool {
        let lm = item.libraryManga

        // Unread filter
        switch currentFilter.unread {
        case .include: if lm.unreadCount <= 0 { return false }
        case .exclude: if lm.unreadCount > 0 { return false }
        case .disabled: break
        }

        // Started filter
        switch currentFilter.started {
        case .include: if !lm.hasStarted { return false }
        case .exclude: if lm.hasStarted { return false }
        case .disabled: break
        }

        // Bookmarked filter
        switch currentFilter.bookmarked {
        case .include: if !lm.hasBookmarks { return false }
        case .exclude: if lm.hasBookmarks { return false }
        case .disabled: break
        }

        // Completed filter (status == 2 is completed in Tachiyomi convention)
        switch currentFilter.completed {
        case .include: if lm.manga.status != 2 { return false }
        case .exclude: if lm.manga.status == 2 { return false }
        case .disabled: break
        }

        // Downloaded filter
        switch currentFilter.downloaded {
        case .include: if item.downloadCount <= 0 && !item.isLocal { return false }
        case .exclude: if item.downloadCount > 0 || item.isLocal { return false }
        case .disabled: break
        }

        // Tracker filters — requires at least one track per requested tracker
        for (trackerId, state) in currentFilter.trackerFilters {
            guard state != .disabled else { continue }
            // Use cached tracker IDs if available; for now we check via stored manga tracker IDs.
            let isTracked = trackedMangaIds[trackerId]?.contains(lm.manga.id) ?? false
            switch state {
            case .include: if !isTracked { return false }
            case .exclude: if isTracked  { return false }
            case .disabled: break
            }
        }

        return true
    }

    // MARK: - Tracker cache

    /// mangaIds grouped by trackerId; updated by calling `updateTrackerCache(tracks:)`.
    /// Populate this from a TrackRepository observation to enable tracker-based filtering.
    private var trackedMangaIds: [Int: Set<Int64>] = [:]

    /// Update the tracker cache from a flat list of (mangaId, trackerId) pairs and
    /// re-process the library so tracker filters take effect immediately.
    func updateTrackerCache(tracks: [(mangaId: Int64, trackerId: Int)]) {
        var cache: [Int: Set<Int64>] = [:]
        for t in tracks {
            cache[t.trackerId, default: []].insert(t.mangaId)
        }
        trackedMangaIds = cache
        processLibraryData(latestLibraryMangas)
    }

    // MARK: - Sorting

    private func applySorting(to items: [LibraryItem]) -> [LibraryItem] {
        let ascending = currentSort.direction.isAscending

        // Random sort: use seeded shuffle so the order is deterministic for a given seed.
        if currentSort.type == .random {
            return seededShuffle(items, seed: currentSort.randomSeed)
        }

        return items.sorted { a, b in
            let result: Bool
            switch currentSort.type {
            case .alphabetical:
                result = a.libraryManga.manga.title.localizedCaseInsensitiveCompare(b.libraryManga.manga.title) == .orderedAscending
            case .lastRead:
                result = a.libraryManga.lastRead < b.libraryManga.lastRead
            case .lastUpdate:
                result = a.libraryManga.manga.lastUpdate < b.libraryManga.manga.lastUpdate
            case .unreadCount:
                result = a.unreadCount < b.unreadCount
            case .totalChapters:
                result = a.libraryManga.totalChapters < b.libraryManga.totalChapters
            case .latestChapter:
                result = a.libraryManga.latestUpload < b.libraryManga.latestUpload
            case .chapterFetchDate:
                result = a.libraryManga.chapterFetchedAt < b.libraryManga.chapterFetchedAt
            case .dateAdded:
                result = a.libraryManga.manga.dateAdded < b.libraryManga.manga.dateAdded
            case .trackerMean:
                result = false // TODO: implement when tracker is ready
            case .random:
                result = false // handled above
            }
            return ascending ? result : !result
        }
    }

    // MARK: - Seeded Shuffle (Fisher-Yates with a simple LCG PRNG)

    private func seededShuffle<T>(_ array: [T], seed: UInt64) -> [T] {
        var rng = SeededRNG(seed: seed)
        var result = array
        for i in stride(from: result.count - 1, through: 1, by: -1) {
            let j = Int(rng.next() % UInt64(i + 1))
            result.swapAt(i, j)
        }
        return result
    }

    func reshuffleRandom() {
        updateSort(currentSort.reshuffled())
    }

    // MARK: - Current Category Items

    var currentCategoryItems: [LibraryItem] {
        guard selectedCategoryIndex < categories.count else { return [] }
        let catId = categories[selectedCategoryIndex].id
        return libraryItems[catId] ?? []
    }

    var totalMangaCount: Int {
        libraryItems.values.reduce(0) { $0 + $1.count }
    }

    // MARK: - Selection

    func toggleSelection(_ mangaId: Int64) {
        if selectedMangaIds.contains(mangaId) {
            selectedMangaIds.remove(mangaId)
        } else {
            selectedMangaIds.insert(mangaId)
        }
        isSelectionMode = !selectedMangaIds.isEmpty
    }

    func selectAll() {
        for item in currentCategoryItems {
            selectedMangaIds.insert(item.id)
        }
        isSelectionMode = true
    }

    func clearSelection() {
        selectedMangaIds.removeAll()
        isSelectionMode = false
    }

    func invertSelection() {
        let currentIds = Set(currentCategoryItems.map(\.id))
        let newSelection = currentIds.subtracting(selectedMangaIds)
        selectedMangaIds = newSelection
        isSelectionMode = !selectedMangaIds.isEmpty
    }

    // MARK: - Actions

    func updateDisplayMode(_ mode: LibraryDisplayMode) {
        displayMode = mode
        preferences.libraryDisplayMode = mode.rawValue
    }

    func updateSort(_ sort: LibrarySort) {
        currentSort = sort
        processLibraryData(latestLibraryMangas)
    }

    func updateFilter(_ filter: LibraryFilter) {
        currentFilter = filter
        processLibraryData(latestLibraryMangas)
    }

    func refresh() async {
        // TODO: trigger library update from sources
    }
}

// MARK: - SeededRNG (LCG — Knuth multiplicative hashing)

private struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        // Mix the seed to avoid degenerate zero-state
        state = seed &+ 0x9e37_79b9_7f4a_7c15
        state = (state ^ (state >> 30)) &* 0xbf58_476d_1ce4_e5b9
        state = (state ^ (state >> 27)) &* 0x94d0_49bb_1331_11eb
        state = state ^ (state >> 31)
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
