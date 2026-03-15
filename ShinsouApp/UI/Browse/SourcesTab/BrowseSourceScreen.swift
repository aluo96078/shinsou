import SwiftUI
import ShinsouSourceAPI
import ShinsouDomain
import ShinsouData
import ShinsouUI
import ShinsouI18n
import Nuke
import NukeUI

struct BrowseSourceScreen: View {
    let sourceId: Int64
    @StateObject private var viewModel: BrowseSourceViewModel
    @State private var showFilterSheet = false
    @State private var showCloudflareSheet = false

    init(sourceId: Int64) {
        self.sourceId = sourceId
        _viewModel = StateObject(wrappedValue: BrowseSourceViewModel(sourceId: sourceId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Browse", selection: $viewModel.selectedTab) {
                Text(MR.strings.browsePopular).tag(0)
                if viewModel.supportsLatest {
                    Text(MR.strings.browseLatest).tag(1)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Content
            if viewModel.isLoading && viewModel.mangas.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = viewModel.errorMessage, viewModel.mangas.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: viewModel.isCloudflareBlocked
                          ? "shield.lefthalf.filled" : "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(viewModel.isCloudflareBlocked ? .orange : .secondary)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    if viewModel.isCloudflareBlocked {
                        Button {
                            showCloudflareSheet = true
                        } label: {
                            Label(MR.strings.browseOpenWebview, systemImage: "globe")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Button(MR.strings.commonRetry) {
                        Task { await viewModel.loadInitial(force: true) }
                    }
                }
                Spacer()
            } else if viewModel.mangas.isEmpty {
                Spacer()
                EmptyStateView(icon: "magnifyingglass", message: MR.strings.browseNoResults)
                Spacer()
            } else {
                mangaGrid
            }
        }
        .navigationTitle(viewModel.sourceName)
        .toolbar {
            if viewModel.hasFilters {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: viewModel.filterState.isModified
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
        .searchable(text: $viewModel.searchQuery, prompt: "Search \(viewModel.sourceName)")
        .onSubmit(of: .search) {
            Task { await viewModel.searchWithFilters() }
        }
        .task { await viewModel.loadInitial() }
        .sheet(isPresented: $showFilterSheet) {
            SourceFilterSheet(filterState: viewModel.filterState) {
                Task { await viewModel.searchWithFilters() }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showCloudflareSheet) {
            CloudflareBypassSheet(siteUrl: viewModel.sourceBaseUrl) {
                Task { await viewModel.loadInitial(force: true) }
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { viewModel.navigateToMangaId != nil },
            set: { if !$0 { viewModel.navigateToMangaId = nil } }
        )) {
            if let mangaId = viewModel.navigateToMangaId {
                MangaDetailScreen(mangaId: mangaId)
            }
        }
    }

    private var mangaGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 10) {
                ForEach(Array(viewModel.mangas.enumerated()), id: \.element.url) { _, manga in
                    sourceMangaCell(manga)
                }

                if viewModel.hasNextPage {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .onAppear {
                            Task { await viewModel.loadMore() }
                        }
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private func sourceMangaCell(_ manga: SManga) -> some View {
        Button {
            Task {
                if let mangaId = await viewModel.insertOrGetMangaId(manga) {
                    viewModel.navigateToMangaId = mangaId
                }
            }
        } label: {
            sourceMangaItem(manga)
        }
        .buttonStyle(.plain)
        .contextMenu {
            let isInLibrary = viewModel.isInLibrary(manga)
            Button {
                Task { await viewModel.toggleFavorite(manga) }
            } label: {
                Label(
                    isInLibrary ? MR.strings.libraryRemoveFromLibrary : MR.strings.mangaAddToLibrary,
                    systemImage: isInLibrary ? "heart.slash" : "heart"
                )
            }
        }
    }

    private func sourceMangaItem(_ manga: SManga) -> some View {
        // Use Color.clear as sizing base to guarantee deterministic layout.
        // The overlay fills the space regardless of image intrinsic size.
        Color(.secondarySystemBackground)
            .aspectRatio(2/3, contentMode: .fit)
            .overlay {
                ZStack(alignment: .bottomLeading) {
                    // Cover image
                    if let url = manga.thumbnailUrl, let imageUrl = URL(string: url) {
                        LazyImage(request: viewModel.imageRequest(for: imageUrl)) { state in
                            if let image = state.image {
                                image
                                    .resizable()
                                    .scaledToFit()
                            } else if state.isLoading {
                                Rectangle().fill(Color.gray.opacity(0.2))
                                    .overlay { ProgressView() }
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.2))
                                    .overlay { Image(systemName: "book.closed").foregroundStyle(.secondary) }
                            }
                        }
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.2))
                            .overlay { Image(systemName: "book.closed").foregroundStyle(.secondary) }
                    }

                    // Dim overlay if in library
                    if viewModel.isInLibrary(manga) {
                        Rectangle().fill(.black.opacity(0.4))
                    }

                    LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)

                    // "In Library" badge
                    if viewModel.isInLibrary(manga) {
                        VStack {
                            HStack {
                                Image(systemName: "books.vertical.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                                    .padding(4)
                                    .background(Color.accentColor.opacity(0.85))
                                    .cornerRadius(4)
                                Spacer()
                            }
                            Spacer()
                        }
                        .padding(4)
                    }

                    Text(manga.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .padding(6)
                }
            }
            .clipped()
            .cornerRadius(8)
    }
}

@MainActor
final class BrowseSourceViewModel: ObservableObject {
    @Published var mangas: [SManga] = []
    @Published var isLoading = false
    @Published var hasNextPage = false
    @Published var selectedTab = 0 { didSet { if oldValue != selectedTab { Task { await loadInitial(force: true) } } } }
    @Published var searchQuery = ""
    @Published var errorMessage: String?
    @Published var isCloudflareBlocked = false
    @Published var navigateToMangaId: Int64?
    private var hasLoaded = false

    /// URLs of manga that are in the user's library (favorites)
    @Published private var libraryUrls: Set<String> = []

    /// Filter state — initialized from source's getFilterList(), refreshed after theme detection
    @Published var filterState: FilterState

    /// Whether this source provides any filters
    var hasFilters: Bool { !filterState.filters.isEmpty || !filterState.defaults.isEmpty }

    let sourceId: Int64
    var sourceName: String { source?.name ?? "Source" }
    var supportsLatest: Bool { source?.supportsLatest ?? false }
    var sourceBaseUrl: String {
        if let stub = source as? StubCatalogueSource, let url = stub.baseUrl {
            return url
        }
        if let jsProxy = source as? JSSourceProxy {
            return jsProxy.baseUrl
        }
        return "https://\(sourceName.lowercased().replacingOccurrences(of: " ", with: ""))"
    }

    private var source: (any CatalogueSource)?
    private var currentPage = 1
    private var isSearchMode = false
    private let mangaRepository: MangaRepository

    /// HTTP headers from the source (Referer, Cookie, etc.) for image loading
    private var sourceHeaders: [String: String] {
        if let jsProxy = source as? JSSourceProxy {
            return jsProxy.sourceHeaders
        }
        return [:]
    }

    /// Build an ImageRequest with source-specific headers for thumbnail loading
    func imageRequest(for url: URL) -> ImageRequest {
        if let urlRequest = NetworkHelper.shared.imageURLRequest(
            for: url.absoluteString, headers: sourceHeaders
        ) {
            return ImageRequest(urlRequest: urlRequest)
        }
        return ImageRequest(url: url)
    }

    init(sourceId: Int64) {
        self.sourceId = sourceId
        let src = SourceManager.shared.getCatalogueSource(id: sourceId)
        self.source = src
        self.filterState = FilterState(filters: src?.getFilterList() ?? [])
        self.mangaRepository = DIContainer.shared.mangaRepository
        Task { await loadLibraryUrls() }
    }

    // MARK: - Library state

    func isInLibrary(_ manga: SManga) -> Bool {
        libraryUrls.contains(manga.url)
    }

    private func loadLibraryUrls() async {
        do {
            let favorites = try await mangaRepository.getFavorites()
            libraryUrls = Set(favorites.filter { $0.source == sourceId }.map(\.url))
        } catch {
            print("Error loading library URLs: \(error)")
        }
    }

    // MARK: - Insert manga to DB and navigate

    /// Insert the SManga into the database (or find existing) and return its database ID.
    func insertOrGetMangaId(_ smanga: SManga) async -> Int64? {
        do {
            // Check if already exists in DB
            if let existing = try await mangaRepository.getMangaByUrlAndSource(url: smanga.url, sourceId: sourceId) {
                return existing.id
            }

            // Insert new manga record
            let manga = Manga(
                source: sourceId,
                url: smanga.url,
                title: smanga.title,
                artist: smanga.artist,
                author: smanga.author,
                description: smanga.description,
                genre: smanga.genre,
                status: Int64(smanga.status.rawValue),
                thumbnailUrl: smanga.thumbnailUrl,
                initialized: smanga.initialized
            )
            let newId = try await mangaRepository.insert(manga: manga)
            return newId
        } catch {
            print("Error inserting manga: \(error)")
            return nil
        }
    }

    // MARK: - Favorite toggle

    func toggleFavorite(_ smanga: SManga) async {
        guard let mangaId = await insertOrGetMangaId(smanga) else { return }

        do {
            let existing = try await mangaRepository.getManga(id: mangaId)
            let isFav = existing?.favorite ?? false
            try await mangaRepository.updatePartial(
                id: mangaId,
                updates: MangaUpdate(
                    favorite: !isFav,
                    dateAdded: isFav ? 0 : Int64(Date().timeIntervalSince1970 * 1000)
                )
            )
            // Refresh library URLs
            await loadLibraryUrls()
        } catch {
            print("Error toggling favorite: \(error)")
        }
    }

    // MARK: - Data loading

    func loadInitial(force: Bool = false) async {
        guard !hasLoaded || force else { return }
        guard let source else {
            errorMessage = "Source not found"
            return
        }
        hasLoaded = true
        isLoading = true
        mangas = []
        currentPage = 0
        isSearchMode = false
        errorMessage = nil
        isCloudflareBlocked = false

        do {
            let result: MangasPage
            if selectedTab == 0 {
                result = try await source.getPopularManga(page: 0)
            } else {
                result = try await source.getLatestUpdates(page: 0)
            }
            mangas = result.mangas
            hasNextPage = result.hasNextPage

            // After first load, theme is detected — refresh filters if empty
            if filterState.defaults.isEmpty {
                let newFilters = source.getFilterList()
                if !newFilters.isEmpty {
                    filterState = FilterState(filters: newFilters)
                }
            }
        } catch let error as ScrapingError where error.isCloudflare {
            isCloudflareBlocked = true
            errorMessage = error.localizedDescription
            print("Cloudflare detected for source: \(error)")
        } catch {
            errorMessage = error.localizedDescription
            print("Error loading source: \(error)")
        }
        isLoading = false
    }

    func loadMore() async {
        guard let source, hasNextPage, !isLoading else { return }
        isLoading = true
        currentPage += 1
        print("[BrowseSourceVM] loadMore: page=\(currentPage), isSearch=\(isSearchMode), existing=\(mangas.count)")

        do {
            let result: MangasPage
            if isSearchMode {
                result = try await source.getSearchManga(page: currentPage, query: searchQuery, filters: filterState.filters)
            } else if selectedTab == 0 {
                result = try await source.getPopularManga(page: currentPage)
            } else {
                result = try await source.getLatestUpdates(page: currentPage)
            }

            // Deduplicate: filter out manga URLs already loaded
            let existingUrls = Set(mangas.map(\.url))
            let newMangas = result.mangas.filter { !existingUrls.contains($0.url) }
            print("[BrowseSourceVM] loadMore: returned=\(result.mangas.count), new=\(newMangas.count), serverHasNext=\(result.hasNextPage)")

            if newMangas.isEmpty && !result.mangas.isEmpty {
                // Server returned results but all are duplicates — stop pagination
                hasNextPage = false
                print("[BrowseSourceVM] loadMore: STOPPED — all duplicates")
            } else {
                mangas.append(contentsOf: newMangas)
                hasNextPage = result.hasNextPage
            }
        } catch {
            print("Error loading more: \(error)")
        }
        isLoading = false
    }

    /// Search with current query and filter state.
    func searchWithFilters() async {
        guard let source else { return }

        // If no query and no filters modified, do nothing
        let hasQuery = !searchQuery.isEmpty
        let hasActiveFilters = filterState.isModified
        guard hasQuery || hasActiveFilters else { return }

        isLoading = true
        mangas = []
        currentPage = 0
        isSearchMode = true
        errorMessage = nil

        do {
            let result = try await source.getSearchManga(page: 0, query: searchQuery, filters: filterState.filters)
            mangas = result.mangas
            hasNextPage = result.hasNextPage
        } catch {
            errorMessage = error.localizedDescription
            print("Error searching: \(error)")
        }
        isLoading = false
    }
}
