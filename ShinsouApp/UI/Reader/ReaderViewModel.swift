import Foundation
import SwiftUI
import ShinsouDomain
import ShinsouSourceAPI
import ShinsouData
import Nuke

enum ReadingMode: Int, CaseIterable {
    case pagerLTR = 0
    case pagerRTL = 1
    case pagerVertical = 2
    case webtoon = 3
    case continuousVertical = 4
}

@MainActor
final class ReaderViewModel: ObservableObject {
    @Published var pages: [Page] = []
    @Published var currentPageIndex: Int = 0
    @Published var isLoading = true
    @Published var error: String?
    @Published var isMenuVisible = true
    @Published var readingMode: ReadingMode = .pagerLTR
    @Published var totalPages: Int = 0
    @Published var chapter: Chapter?
    @Published var manga: Manga?

    // Settings
    @Published var keepScreenOn = true
    @Published var showPageNumber = true
    @Published var fullscreen = true
    @Published var volumeKeysEnabled = false

    // Volume button handler (shared singleton, HUD 抑制常駐)
    let volumeButtonHandler = VolumeButtonHandler.shared

    // Color Filter
    @Published var colorFilterType: ColorFilterType = .none
    @Published var customBrightness: Float = 0

    // Image processing
    @Published var splitTallImages: Bool = false

    // Webtoon layout
    @Published var webtoonSidePadding: Double = 0

    // Chapter neighbours (populated when navigating)
    @Published var previousChapterName: String?
    @Published var nextChapterName: String?

    /// The referer URL to send with image requests (typically the manga source's base URL).
    @Published var refererUrl: String?

    /// Extra HTTP headers from the source (Cookie, custom User-Agent, etc.)
    @Published var sourceHeaders: [String: String] = [:]

    /// Whether a chapter transition is in progress.
    @Published var isTransitioning = false

    // MARK: - Prefetch

    /// Cache of resolved image URLs (page index → image URL).
    /// Used to avoid redundant URL resolution for E-Hentai style sources.
    private(set) var resolvedImageUrls: [Int: String] = [:]

    /// Maximum number of pages to prefetch ahead of the current page.
    private let maxPrefetchAhead = 20

    /// Task that performs sequential URL resolution + image prefetching.
    private var prefetchTask: Task<Void, Never>?

    /// Nuke prefetcher instance for image pre-loading.
    private let imagePrefetcher = ImagePrefetcher()

    let mangaId: Int64
    /// The current chapter ID — mutable to support chapter navigation.
    private(set) var currentChapterId: Int64

    private let mangaRepository: MangaRepository
    private let chapterRepository: ChapterRepository
    private let historyRepository: HistoryRepository
    private let preferences: AppPreferences
    private var startTime: Date?

    /// All chapters for this manga, sorted by sourceOrder ascending.
    private var allChapters: [Chapter] = []

    init(
        mangaId: Int64,
        chapterId: Int64,
        mangaRepository: MangaRepository,
        chapterRepository: ChapterRepository,
        historyRepository: HistoryRepository,
        preferences: AppPreferences
    ) {
        self.mangaId = mangaId
        self.currentChapterId = chapterId
        self.mangaRepository = mangaRepository
        self.chapterRepository = chapterRepository
        self.historyRepository = historyRepository
        self.preferences = preferences

        self.readingMode = ReadingMode(rawValue: preferences.defaultReadingMode) ?? .pagerLTR
        self.keepScreenOn = preferences.keepScreenOn
        self.showPageNumber = preferences.showPageNumber
        self.fullscreen = preferences.fullscreen
        self.volumeKeysEnabled = UserDefaults.standard.bool(forKey: SettingsKeys.volumeKeys)
        self.splitTallImages = UserDefaults.standard.bool(forKey: SettingsKeys.splitTallImages)
        self.webtoonSidePadding = UserDefaults.standard.double(forKey: SettingsKeys.webtoonSidePadding)

        setupVolumeKeys()
    }

    private func setupVolumeKeys() {
        volumeButtonHandler.onVolumeButtonPressed = { [weak self] event in
            guard let self, self.volumeKeysEnabled else { return }
            Task { @MainActor in
                switch event {
                case .up:
                    self.goToPreviousPage()
                case .down:
                    self.goToNextPage()
                }
            }
        }
    }

    func goToNextPage() {
        if currentPageIndex < totalPages - 1 {
            onPageChanged(currentPageIndex + 1)
        } else {
            Task { await moveToNextChapter() }
        }
    }

    func goToPreviousPage() {
        if currentPageIndex > 0 {
            onPageChanged(currentPageIndex - 1)
        } else {
            Task { await moveToPreviousChapter() }
        }
    }

    func loadChapter() async {
        isLoading = true
        error = nil
        startTime = Date()

        // Clear debug logs for this load
        await MainActor.run { DebugLogger.shared.clear() }

        do {
            // Load manga info
            manga = try await mangaRepository.getManga(id: mangaId)

            // Load all chapters for navigation
            allChapters = try await chapterRepository.getChaptersByMangaId(mangaId: mangaId)
            allChapters.sort { $0.sourceOrder < $1.sourceOrder }

            // Load current chapter
            chapter = try await chapterRepository.getChapter(id: currentChapterId)

            guard let chapter, let manga else {
                self.error = "無法載入章節資料"
                isLoading = false
                return
            }

            // Determine the source and fetch pages
            guard let source = SourceManager.shared.getSource(id: manga.source) else {
                self.error = "找不到來源（Source ID: \(manga.source)）"
                isLoading = false
                return
            }

            // Build SChapter for the source API call
            let schapter = SChapter(
                url: chapter.url,
                name: chapter.name,
                scanlator: chapter.scanlator,
                dateUpload: chapter.dateUpload,
                chapterNumber: chapter.chapterNumber
            )

            // Determine referer from source base URL
            refererUrl = resolveReferer(source: source, chapterUrl: chapter.url)

            // Extract source-specific headers (Cookie, etc.)
            if let jsProxy = source as? JSSourceProxy {
                sourceHeaders = jsProxy.sourceHeaders
            }

            // Fetch page list from source
            let fetchedPages = try await source.getPageList(chapter: schapter)

            if fetchedPages.isEmpty {
                // Check plugin logs for specific messages (e.g. paid chapter warnings)
                var pluginLogText = ""
                if let jsProxy = source as? JSSourceProxy {
                    pluginLogText = jsProxy.recentPluginLogs.joined(separator: "\n")
                }

                // If plugin provided a warning (e.g. paid chapter), show it prominently
                if !pluginLogText.isEmpty {
                    self.error = pluginLogText + "\n\n來源：\(source.name)\nURL：\(chapter.url)"
                } else {
                    let debugInfo = DebugLogger.shared.recentText
                    self.error = "此章節沒有可用的頁面\n\n來源：\(source.name)\nURL：\(chapter.url)\n\n--- 除錯日誌 ---\n\(debugInfo)"
                }
                isLoading = false
                return
            }

            pages = fetchedPages
            totalPages = pages.count

            // Update chapter neighbour names for transition screens
            updateChapterNeighbours()

            // Restore last page read
            if chapter.lastPageRead > 0 && chapter.lastPageRead < totalPages {
                currentPageIndex = chapter.lastPageRead
            } else {
                currentPageIndex = 0
            }

            // Record history entry
            try? await historyRepository.upsert(
                chapterId: chapter.id,
                readAt: Int64(Date().timeIntervalSince1970 * 1000)
            )

            isLoading = false

            // Start prefetching from the current page
            startPrefetching(from: currentPageIndex)
        } catch {
            self.error = "載入頁面失敗：\(error.localizedDescription)"
            isLoading = false
        }
    }

    func onPageChanged(_ index: Int) {
        guard index >= 0, index < totalPages else { return }
        currentPageIndex = index
        saveProgress()
    }

    func toggleMenu() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isMenuVisible.toggle()
        }
    }

    // MARK: - Prefetch

    /// Called by the reader when a page finishes loading its image.
    /// Stores the resolved URL and starts prefetching subsequent pages.
    func onPageImageLoaded(_ index: Int, resolvedUrl: String?) {
        if let url = resolvedUrl {
            resolvedImageUrls[index] = url
        }
        startPrefetching(from: index + 1)
    }

    /// Returns a previously resolved image URL for the given page index, if available.
    func resolvedImageUrl(for index: Int) -> String? {
        resolvedImageUrls[index]
    }

    /// Start prefetching pages sequentially from `startIndex`.
    /// Resolves image URLs (for sources like E-Hentai) and pre-downloads images.
    private func startPrefetching(from startIndex: Int) {
        prefetchTask?.cancel()
        let pages = self.pages
        let headers = self.sourceHeaders
        let referer = self.refererUrl
        let maxAhead = self.maxPrefetchAhead

        prefetchTask = Task { [weak self] in
            let endIndex = min(startIndex + maxAhead, pages.count)
            guard startIndex < endIndex else { return }

            for i in startIndex..<endIndex {
                guard !Task.isCancelled else { break }

                // Skip if already resolved
                let alreadyResolved = await MainActor.run { self?.resolvedImageUrls[i] }
                if alreadyResolved != nil { continue }

                let page = pages[i]
                var imageUrl = page.imageUrl

                // Resolve image URL if needed (E-Hentai style: viewer page → actual image)
                if imageUrl == nil, !page.url.isEmpty {
                    imageUrl = await ReaderPageViewController.resolveImageUrl(
                        from: page.url, headers: headers
                    )
                }

                guard !Task.isCancelled else { break }

                if let imageUrl {
                    await MainActor.run {
                        self?.resolvedImageUrls[i] = imageUrl
                    }
                    // Prefetch the image via Nuke
                    self?.prefetchImage(urlString: imageUrl, headers: headers, referer: referer)
                }
            }
        }
    }

    /// Pre-download an image into Nuke's cache.
    private nonisolated func prefetchImage(urlString: String, headers: [String: String], referer: String?) {
        guard let urlRequest = NetworkHelper.shared.imageURLRequest(
            for: urlString, headers: headers, referer: referer
        ) else { return }
        let request = ImageRequest(urlRequest: urlRequest)
        Task { @MainActor [weak self] in
            self?.imagePrefetcher.startPrefetching(with: [request])
        }
    }

    // MARK: - Chapter Navigation

    func moveToNextChapter() async {
        guard !isTransitioning else { return }
        guard let currentChapter = chapter else { return }

        // Chapters are sorted by sourceOrder ascending.
        // "Next" chapter = higher sourceOrder (later chapter)
        let currentIdx = allChapters.firstIndex(where: { $0.id == currentChapter.id })
        guard let idx = currentIdx else { return }

        // Find next chapter that isn't already read (respecting skip settings)
        let candidates = allChapters.suffix(from: allChapters.index(after: idx))
        guard let nextChapter = candidates.first(where: { shouldNavigateTo($0) }) ?? candidates.first else {
            return // No next chapter
        }

        await switchToChapter(nextChapter.id)
    }

    func moveToPreviousChapter() async {
        guard !isTransitioning else { return }
        guard let currentChapter = chapter else { return }

        let currentIdx = allChapters.firstIndex(where: { $0.id == currentChapter.id })
        guard let idx = currentIdx, idx > 0 else { return }

        // Find previous chapter
        let candidates = allChapters.prefix(upTo: idx).reversed()
        guard let prevChapter = candidates.first(where: { shouldNavigateTo($0) }) ?? candidates.first else {
            return
        }

        await switchToChapter(prevChapter.id)
    }

    /// Load a different chapter in-place.
    private func switchToChapter(_ chapterId: Int64) async {
        isTransitioning = true

        // Clear prefetch state for old chapter
        prefetchTask?.cancel()
        resolvedImageUrls.removeAll()

        // Mark current chapter as read if we were on the last page
        if let chapter, currentPageIndex >= totalPages - 1 {
            try? await chapterRepository.updatePartial(
                id: chapter.id, read: true, bookmark: nil, lastPageRead: currentPageIndex
            )
        }

        currentChapterId = chapterId
        await loadChapter()
        isTransitioning = false
    }

    /// Whether the chapter should be navigated to based on skip preferences.
    private func shouldNavigateTo(_ chapter: Chapter) -> Bool {
        let skipRead = UserDefaults.standard.bool(forKey: SettingsKeys.skipReadChapters)
        if skipRead && chapter.read { return false }
        return true
    }

    /// Update the previous/next chapter names for the transition screens.
    private func updateChapterNeighbours() {
        guard let currentChapter = chapter else { return }
        let idx = allChapters.firstIndex(where: { $0.id == currentChapter.id })
        guard let idx else { return }

        previousChapterName = idx > 0 ? allChapters[idx - 1].name : nil
        nextChapterName = idx < allChapters.count - 1 ? allChapters[idx + 1].name : nil
    }

    // MARK: - Reading Mode

    func cycleReadingMode() {
        let allCases = ReadingMode.allCases
        guard let idx = allCases.firstIndex(of: readingMode) else { return }
        let nextIdx = (idx + 1) % allCases.count
        readingMode = allCases[nextIdx]
        preferences.defaultReadingMode = readingMode.rawValue
    }

    // MARK: - Bookmark

    func toggleBookmark() async {
        guard let chapter else { return }
        let newBookmark = !chapter.bookmark
        do {
            try await chapterRepository.updatePartial(
                id: chapter.id,
                read: nil,
                bookmark: newBookmark,
                lastPageRead: nil
            )
            self.chapter = try await chapterRepository.getChapter(id: chapter.id)
        } catch {
            print("Error toggling bookmark: \(error)")
        }
    }

    // MARK: - Chapter List

    /// All chapters sorted by sourceOrder ascending, exposed for the chapter list sheet.
    var allChaptersSorted: [Chapter] {
        allChapters
    }

    /// Public wrapper for switching to a chapter by its ID.
    func switchToChapterById(_ chapterId: Int64) async {
        await switchToChapter(chapterId)
    }

    // MARK: - Progress

    private func saveProgress() {
        guard let chapter else { return }
        Task {
            do {
                let isLastPage = currentPageIndex >= totalPages - 1
                try await chapterRepository.updatePartial(
                    id: chapter.id,
                    read: isLastPage ? true : nil,
                    bookmark: nil,
                    lastPageRead: currentPageIndex
                )
                // Update history
                try await historyRepository.upsert(
                    chapterId: chapter.id,
                    readAt: Int64(Date().timeIntervalSince1970 * 1000)
                )
            } catch {
                print("Error saving progress: \(error)")
            }
        }
    }

    // MARK: - Helpers

    /// Resolves the referer URL to use for image requests.
    private func resolveReferer(source: any Source, chapterUrl: String) -> String? {
        // JS plugin sources — use baseUrl (which matches the plugin's Referer header)
        if let jsProxy = source as? JSSourceProxy, !jsProxy.baseUrl.isEmpty {
            return jsProxy.baseUrl
        }
        // Try to extract base URL from the source
        if let catalogue = source as? StubCatalogueSource, let base = catalogue.baseUrl {
            return base
        }
        // Try from chapter URL
        if chapterUrl.hasPrefix("http"), let url = URL(string: chapterUrl) {
            return "\(url.scheme ?? "https")://\(url.host ?? "")"
        }
        return nil
    }
}
