import Foundation
import SwiftUI
import ShinsouDomain
import ShinsouData
import ShinsouSourceAPI

@MainActor
final class MangaDetailViewModel: ObservableObject {
    @Published var manga: Manga?
    @Published var chapters: [Chapter] = []
    @Published var isLoading = true
    @Published var isRefreshingFromSource = false
    @Published var isFavorite = false
    @Published var selectedChapterIds: Set<Int64> = []
    @Published var isSelectionMode = false

    // Chapter display settings
    @Published var sortAscending = false
    @Published var showRead = true
    @Published var showUnread = true
    @Published var showBookmarked = true
    @Published var showDownloaded = true

    // Scanlator filter (7.8)
    @Published var excludedScanlators: Set<String> = []

    // Category picker
    @Published var showCategoryPicker = false

    // Chapter skip settings (7.12) — backed by UserDefaults
    @AppStorage(SettingsKeys.skipReadChapters) var skipReadChapters = false
    @AppStorage(SettingsKeys.skipFilteredChapters) var skipFilteredChapters = false
    @AppStorage(SettingsKeys.skipDuplicateChapters) var skipDuplicateChapters = false

    let mangaId: Int64
    private let mangaRepository: MangaRepository
    private let chapterRepository: ChapterRepository
    let categoryRepository: CategoryRepository

    private var allChapters: [Chapter] = []
    private var mangaObservation: Task<Void, Never>?
    private var chapterObservation: Task<Void, Never>?
    private var hasFetchedFromSource = false

    init(mangaId: Int64, mangaRepository: MangaRepository, chapterRepository: ChapterRepository, categoryRepository: CategoryRepository) {
        self.mangaId = mangaId
        self.mangaRepository = mangaRepository
        self.chapterRepository = chapterRepository
        self.categoryRepository = categoryRepository
        startObserving()
    }

    deinit {
        mangaObservation?.cancel()
        chapterObservation?.cancel()
    }

    // MARK: - Scanlators (7.8)

    /// All unique, non-empty scanlators from the full (unfiltered) chapter list.
    var availableScanlators: Set<String> {
        Set(allChapters.compactMap { $0.scanlator }.filter { !$0.isEmpty })
    }

    func toggleExcludedScanlator(_ scanlator: String) {
        if excludedScanlators.contains(scanlator) {
            excludedScanlators.remove(scanlator)
        } else {
            excludedScanlators.insert(scanlator)
        }
        refreshSortFilter()
    }

    // MARK: - Missing Chapters (7.9)

    /// Ranges of missing chapter numbers, computed from the sorted display list.
    /// Only considers chapters with a valid chapterNumber (>= 0).
    var missingChapterRanges: [(Double, Double)] {
        let validNums = chapters
            .map(\.chapterNumber)
            .filter { $0 >= 0 }
            .sorted()

        guard validNums.count >= 2 else { return [] }

        var gaps: [(Double, Double)] = []
        for i in 0 ..< validNums.count - 1 {
            let current = validNums[i]
            let next = validNums[i + 1]
            // A gap of more than 1 that isn't just a decimal (.5) chapter
            if next - current > 1.0 + 1e-9 {
                gaps.append((current, next))
            }
        }
        return gaps
    }

    // MARK: - Duplicate Chapters (7.11)

    /// Maps chapterNumber → [Chapter] for numbers with more than one entry.
    var duplicateChapterGroups: [Double: [Chapter]] {
        let grouped = Dictionary(grouping: chapters, by: \.chapterNumber)
        return grouped.filter { $0.value.count > 1 && $0.key >= 0 }
    }

    /// Set of chapter IDs that are considered duplicates (same number, different scanlator).
    var duplicateChapterIds: Set<Int64> {
        Set(duplicateChapterGroups.values.flatMap { $0 }.map(\.id))
    }

    /// Mark all but the first (by sourceOrder) duplicate as read for a given chapterNumber.
    func autoMarkDuplicatesRead(for chapterNumber: Double) async {
        guard let duplicates = duplicateChapterGroups[chapterNumber] else { return }
        let sorted = duplicates.sorted { $0.sourceOrder < $1.sourceOrder }
        let toMark = sorted.dropFirst().map(\.id)
        await markChaptersRead(Array(toMark), read: true)
    }

    func autoMarkAllDuplicatesRead() async {
        for chapterNumber in duplicateChapterGroups.keys {
            await autoMarkDuplicatesRead(for: chapterNumber)
        }
    }

    // MARK: - Continue Reading

    /// The chapter to resume reading from: the first unread chapter (by sourceOrder ascending).
    /// If all chapters are read, returns the last chapter.
    /// If the user was mid-chapter (lastPageRead > 0), that chapter takes priority.
    var continueReadingChapter: Chapter? {
        let sorted = allChapters.sorted { $0.sourceOrder < $1.sourceOrder }
        // Priority: chapter with reading progress (lastPageRead > 0 and not fully read)
        if let inProgress = sorted.first(where: { !$0.read && $0.lastPageRead > 0 }) {
            return inProgress
        }
        // Otherwise: first unread chapter
        if let firstUnread = sorted.first(where: { !$0.read }) {
            return firstUnread
        }
        // All read: return the last chapter
        return sorted.last
    }

    /// Label for the continue reading button.
    var continueReadingLabel: String {
        let sorted = allChapters.sorted { $0.sourceOrder < $1.sourceOrder }
        if sorted.contains(where: { !$0.read && $0.lastPageRead > 0 }) {
            return "繼續閱讀"
        }
        if sorted.contains(where: { !$0.read }) {
            return "開始閱讀"
        }
        return "重新閱讀"
    }

    // MARK: - Notes (7.3)

    func saveNotes(_ notes: String) async {
        guard let manga else { return }
        do {
            try await mangaRepository.updatePartial(
                id: manga.id,
                updates: MangaUpdate(notes: notes)
            )
        } catch {
            print("Error saving notes: \(error)")
        }
    }

    // MARK: - Observation

    private func startObserving() {
        mangaObservation = Task { [weak self] in
            guard let self else { return }
            let stream = self.mangaRepository.observeManga(id: self.mangaId)
            for await m in stream {
                guard !Task.isCancelled else { return }
                self.manga = m
                self.isFavorite = m?.favorite ?? false
                self.isLoading = false

                // Fetch from source if manga is not initialized (coming from browse)
                if let m, !self.hasFetchedFromSource {
                    self.hasFetchedFromSource = true
                    let needInfo = !m.initialized
                    let needChapters = self.allChapters.isEmpty
                    if needInfo || needChapters {
                        Task { await self.fetchFromSource(info: needInfo, chapters: needChapters) }
                    }
                }
            }
        }

        chapterObservation = Task { [weak self] in
            guard let self else { return }
            let stream = self.chapterRepository.observeChaptersByMangaId(mangaId: self.mangaId)
            for await chs in stream {
                guard !Task.isCancelled else { return }
                self.allChapters = chs
                self.chapters = self.filterAndSortChapters(chs)
            }
        }
    }

    // MARK: - Source Fetching

    /// Fetch manga details and/or chapters from the source and save to DB.
    func fetchFromSource(info: Bool = true, chapters: Bool = true) async {
        guard let manga else { return }
        let source = SourceManager.shared.getSource(id: manga.source)
        guard let source else { return }

        isRefreshingFromSource = true
        defer { isRefreshingFromSource = false }

        let smanga = SManga(
            url: manga.url,
            title: manga.title,
            artist: manga.artist,
            author: manga.author,
            description: manga.description,
            genre: manga.genre,
            status: MangaStatus(rawValue: Int(manga.status)) ?? .unknown,
            thumbnailUrl: manga.thumbnailUrl,
            initialized: manga.initialized
        )

        // Fetch manga details
        if info {
            do {
                let details = try await source.getMangaDetails(manga: smanga)

                // Only update title if the new one is meaningful and not longer junk
                let newTitle: String?
                if !details.title.isEmpty,
                   details.title != manga.title,
                   details.title.count <= manga.title.count + 10 {
                    newTitle = details.title
                } else {
                    newTitle = nil // keep existing title
                }

                // Filter genre: remove empty, whitespace-only, or unrenderable entries
                let filteredGenre = details.genre?.filter { genre in
                    let trimmed = genre.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard trimmed.count >= 2 else { return false }
                    // Must contain at least one letter/CJK character
                    return trimmed.unicodeScalars.contains { CharacterSet.letters.contains($0) }
                }

                try await mangaRepository.updatePartial(
                    id: manga.id,
                    updates: MangaUpdate(
                        title: newTitle,
                        author: details.author,
                        artist: details.artist,
                        description: details.description,
                        genre: filteredGenre?.isEmpty == true ? nil : filteredGenre,
                        status: Int64(details.status.rawValue),
                        thumbnailUrl: details.thumbnailUrl ?? manga.thumbnailUrl,
                        initialized: true
                    )
                )
            } catch {
                print("Error fetching manga details from source: \(error)")
            }
        }

        // Fetch chapters
        if chapters {
            do {
                let sourceChapters = try await source.getChapterList(manga: smanga)
                let now = Int64(Date().timeIntervalSince1970 * 1000)

                // Get existing chapters to avoid duplicates
                let existingChapters = try await chapterRepository.getChaptersByMangaId(mangaId: manga.id)
                let existingUrls = Set(existingChapters.map(\.url))

                var newChapters: [Chapter] = []
                for (index, sch) in sourceChapters.enumerated() {
                    if existingUrls.contains(sch.url) { continue }
                    newChapters.append(Chapter(
                        mangaId: manga.id,
                        url: sch.url,
                        name: sch.name,
                        scanlator: sch.scanlator,
                        chapterNumber: sch.chapterNumber,
                        sourceOrder: index,
                        dateFetch: now,
                        dateUpload: sch.dateUpload
                    ))
                }

                if !newChapters.isEmpty {
                    try await chapterRepository.insertAll(chapters: newChapters)
                }
            } catch {
                print("Error fetching chapters from source: \(error)")
            }
        }
    }

    /// Manual refresh triggered by pull-to-refresh.
    func refreshFromSource() async {
        await fetchFromSource(info: true, chapters: true)
    }

    private func filterAndSortChapters(_ chapters: [Chapter]) -> [Chapter] {
        var filtered = chapters

        if !showRead {
            filtered = filtered.filter { !$0.read }
        }
        if !showUnread {
            filtered = filtered.filter { $0.read }
        }
        if !showBookmarked {
            filtered = filtered.filter { !$0.bookmark }
        }

        // Scanlator filter (7.8)
        if !excludedScanlators.isEmpty {
            filtered = filtered.filter { chapter in
                guard let scanlator = chapter.scanlator, !scanlator.isEmpty else { return true }
                return !excludedScanlators.contains(scanlator)
            }
        }

        if sortAscending {
            filtered.sort { $0.sourceOrder < $1.sourceOrder }
        } else {
            filtered.sort { $0.sourceOrder > $1.sourceOrder }
        }

        return filtered
    }

    // MARK: - Chapter Navigation Helpers (7.12)

    /// Returns the next chapter ID to open, respecting skip settings.
    func nextChapterId(after chapterId: Int64) -> Int64? {
        let sorted = allChapters.sorted { $0.sourceOrder < $1.sourceOrder }
        guard let idx = sorted.firstIndex(where: { $0.id == chapterId }) else { return nil }
        let candidates = sorted.dropFirst(idx + 1)
        return candidates.first(where: { shouldNavigateTo($0) })?.id
    }

    /// Returns the previous chapter ID to open, respecting skip settings.
    func previousChapterId(before chapterId: Int64) -> Int64? {
        let sorted = allChapters.sorted { $0.sourceOrder > $1.sourceOrder }
        guard let idx = sorted.firstIndex(where: { $0.id == chapterId }) else { return nil }
        let candidates = sorted.dropFirst(idx + 1)
        return candidates.first(where: { shouldNavigateTo($0) })?.id
    }

    private func shouldNavigateTo(_ chapter: Chapter) -> Bool {
        if skipReadChapters && chapter.read { return false }
        if skipFilteredChapters && !chapters.contains(where: { $0.id == chapter.id }) { return false }
        if skipDuplicateChapters && duplicateChapterIds.contains(chapter.id) { return false }
        return true
    }

    // MARK: - Actions

    func toggleFavorite() async {
        guard let manga else { return }

        if manga.favorite {
            // Removing from library — clear favorite and categories
            do {
                try await mangaRepository.updatePartial(
                    id: manga.id,
                    updates: MangaUpdate(favorite: false, dateAdded: 0)
                )
                try await categoryRepository.setMangaCategories(mangaId: manga.id, categoryIds: [])
            } catch {
                print("Error removing favorite: \(error)")
            }
        } else {
            // Adding to library
            do {
                let categories = try await categoryRepository.getAll()
                let userCategories = categories.filter { !$0.isSystemCategory }

                // Set as favorite first
                try await mangaRepository.updatePartial(
                    id: manga.id,
                    updates: MangaUpdate(
                        favorite: true,
                        dateAdded: Int64(Date().timeIntervalSince1970 * 1000)
                    )
                )

                if userCategories.isEmpty {
                    // No user categories — goes to Default automatically (no manga_category record needed)
                    return
                }

                // Check default category setting
                let defaultCatSetting = UserDefaults.standard.string(forKey: SettingsKeys.defaultCategory) ?? "Default"

                if defaultCatSetting == "__ask__" {
                    // Always Ask — show picker
                    showCategoryPicker = true
                } else if defaultCatSetting == "Default" {
                    // Default — no manga_category record needed, COALESCE handles it
                    return
                } else if let targetCat = userCategories.first(where: { $0.name == defaultCatSetting }) {
                    // Assign to the specified default category
                    try await categoryRepository.setMangaCategories(mangaId: manga.id, categoryIds: [targetCat.id])
                } else {
                    // Fallback to Default
                    return
                }
            } catch {
                print("Error toggling favorite: \(error)")
            }
        }
    }

    func markChaptersRead(_ chapterIds: [Int64], read: Bool) async {
        for id in chapterIds {
            do {
                try await chapterRepository.updatePartial(
                    id: id,
                    read: read,
                    bookmark: nil,
                    lastPageRead: read ? nil : 0
                )
            } catch {
                print("Error updating chapter: \(error)")
            }
        }
    }

    func toggleBookmark(_ chapterIds: [Int64]) async {
        for id in chapterIds {
            if let ch = chapters.first(where: { $0.id == id }) {
                do {
                    try await chapterRepository.updatePartial(
                        id: id,
                        read: nil,
                        bookmark: !ch.bookmark,
                        lastPageRead: nil
                    )
                } catch {
                    print("Error toggling bookmark: \(error)")
                }
            }
        }
    }

    func deleteChapters(_ chapterIds: [Int64]) async {
        do {
            try await chapterRepository.delete(chapterIds: chapterIds)
        } catch {
            print("Error deleting chapters: \(error)")
        }
    }

    func toggleSelection(_ chapterId: Int64) {
        if selectedChapterIds.contains(chapterId) {
            selectedChapterIds.remove(chapterId)
        } else {
            selectedChapterIds.insert(chapterId)
        }
        isSelectionMode = !selectedChapterIds.isEmpty
    }

    func selectAll() {
        selectedChapterIds = Set(chapters.map(\.id))
        isSelectionMode = true
    }

    func clearSelection() {
        selectedChapterIds.removeAll()
        isSelectionMode = false
    }

    func refreshSortFilter() {
        chapterObservation?.cancel()
        chapterObservation = Task { [weak self] in
            guard let self else { return }
            let stream = self.chapterRepository.observeChaptersByMangaId(mangaId: self.mangaId)
            for await chs in stream {
                guard !Task.isCancelled else { return }
                self.allChapters = chs
                self.chapters = self.filterAndSortChapters(chs)
            }
        }
    }
}
