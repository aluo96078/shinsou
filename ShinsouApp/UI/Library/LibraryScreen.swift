import SwiftUI
import ShinsouDomain
import ShinsouUI
import ShinsouI18n

struct LibraryScreen: View {
    @StateObject private var viewModel: LibraryViewModel
    @State private var showSettings = false
    @State private var showSearch = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var showCategoryManagement = false
    @State private var showCategoryPicker = false
    /// When non-nil, triggers navigation to the manga detail screen via the NavigationStack path.
    @State private var continueReadingTarget: Int64? = nil
    @State private var readerDestination: ReaderDestination? = nil

    init(viewModel: @autoclosure @escaping () -> LibraryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showSearch {
                    librarySearchBar
                }

                ZStack(alignment: .bottom) {
                    if viewModel.isLoading {
                        LoadingView()
                } else if viewModel.totalMangaCount == 0,
                          viewModel.categories.count <= 1,
                          !viewModel.currentFilter.hasActiveFilters {
                    EmptyStateView(
                        icon: "books.vertical",
                        message: "Add manga from Browse to get started"
                        )
                    } else {
                        libraryContent
                    }

                    // Continue Reading floating button — shown whenever there is a
                    // recently-read manga that still has unread chapters.
                    if let lastRead = viewModel.lastReadItem,
                       lastRead.unreadCount > 0,
                       !viewModel.isSelectionMode {
                        continueReadingBanner(for: lastRead)
                            .padding(.bottom, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.lastReadItem?.id)
            .navigationTitle(MR.strings.tabLibrary)
            .toolbar { toolbarContent }
            .task {
                await viewModel.refreshCategories()
            }
            .onChange(of: showSearch) { isPresented in
                isSearchFieldFocused = isPresented
            }
            .sheet(isPresented: $showSettings) {
                LibrarySettingsSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCategoryManagement, onDismiss: {
                Task { await viewModel.refreshCategories() }
            }) {
                CategoryManagementSheet(
                    categoryRepository: DIContainer.shared.categoryRepository,
                    onCategoriesChanged: {
                        Task { await viewModel.refreshCategories() }
                    }
                )
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerSheet(
                    categoryRepository: DIContainer.shared.categoryRepository,
                    mangaIds: Array(viewModel.selectedMangaIds)
                ) {
                    viewModel.clearSelection()
                }
                .presentationDetents([.medium])
            }
            .refreshable {
                await viewModel.refresh()
            }
            .navigationDestination(for: Int64.self) { mangaId in
                MangaDetailScreen(mangaId: mangaId)
            }
            .fullScreenCover(item: $readerDestination) { dest in
                ReaderContainerView(mangaId: dest.mangaId, chapterId: dest.chapterId)
            }
        }
    }

    // MARK: - Search

    private var librarySearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(MR.strings.librarySearchPrompt, text: $viewModel.searchQuery)
                .focused($isSearchFieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            Button {
                showSearch = false
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close search")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Continue Reading Banner

    @ViewBuilder
    private func continueReadingBanner(for item: LibraryItem) -> some View {
        Button {
            // Try to open the reader directly with the next unread chapter
            Task {
                let chapters = try? await DIContainer.shared.chapterRepository
                    .getChaptersByMangaId(mangaId: item.id)
                // Sources return chapters newest-first, so sourceOrder=0 is the latest chapter.
                // Sort descending by sourceOrder = story order (earliest first).
                let sorted = (chapters ?? []).sorted { $0.sourceOrder > $1.sourceOrder }
                if let nextUnread = sorted.first(where: { !$0.read }) ?? sorted.last {
                    readerDestination = ReaderDestination(mangaId: item.id, chapterId: nextUnread.id)
                } else {
                    // Fallback: navigate to detail
                    continueReadingTarget = item.id
                }
            }
        } label: {
            HStack(spacing: 12) {
                // Cover thumbnail
                AsyncCoverView(thumbnailUrl: item.libraryManga.manga.thumbnailUrl)
                    .frame(width: 40, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(MR.strings.libraryContinueReading)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.libraryManga.manga.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(item.unreadCount) chapter\(item.unreadCount == 1 ? "" : "s") left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "play.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    // MARK: - Inline cover helper (avoids dependency on undefined MangaCoverImage)

    private struct AsyncCoverView: View {
        let thumbnailUrl: String?

        var body: some View {
            if let urlString = thumbnailUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Rectangle().fill(Color.secondary.opacity(0.2))
                    }
                }
            } else {
                Rectangle().fill(Color.secondary.opacity(0.2))
            }
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        VStack(spacing: 0) {
            // Category tabs - only show when there are multiple categories
            if viewModel.categories.count > 1 {
                categoryTabs
                    .id(viewModel.categories.map(\.id))
                Divider()
            }

            // Paged content per category
            TabView(selection: $viewModel.selectedCategoryIndex) {
                ForEach(Array(viewModel.categories.enumerated()), id: \.element.id) { index, category in
                    libraryPage(for: category)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .id(viewModel.categories.map(\.id)) // force rebuild when categories change
        }
    }

    private var categoryTabs: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(viewModel.categories.enumerated()), id: \.element.id) { index, category in
                        Button {
                            withAnimation { viewModel.selectedCategoryIndex = index }
                        } label: {
                            VStack(spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(category.name)
                                        .font(.subheadline)
                                    let count = viewModel.libraryItems[category.id]?.count ?? 0
                                    if count > 0 {
                                        Text("\(count)")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.quaternary, in: Capsule())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)

                                Rectangle()
                                    .fill(index == viewModel.selectedCategoryIndex ? Color.accentColor : .clear)
                                    .frame(height: 2)
                            }
                            .foregroundStyle(index == viewModel.selectedCategoryIndex ? Color.accentColor : .secondary)
                        }
                        .id(index)
                    }
                }
            }
            .onChange(of: viewModel.selectedCategoryIndex) { newIndex in
                withAnimation { proxy.scrollTo(newIndex, anchor: .center) }
            }
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func libraryPage(for category: ShinsouDomain.Category) -> some View {
        let items = viewModel.libraryItems[category.id] ?? []

        if items.isEmpty {
            EmptyStateView(
                icon: viewModel.currentFilter.hasActiveFilters ? "line.3.horizontal.decrease.circle" : "tray",
                message: viewModel.currentFilter.hasActiveFilters ? "No matches. Try changing your filters." : "Empty category"
            )
        } else {
            switch viewModel.displayMode {
            case .compactGrid:
                LibraryGridView(items: items, mode: .compact, viewModel: viewModel)
            case .comfortableGrid:
                LibraryGridView(items: items, mode: .comfortable, viewModel: viewModel)
            case .coverOnlyGrid:
                LibraryGridView(items: items, mode: .coverOnly, viewModel: viewModel)
            case .list:
                LibraryListView(items: items, viewModel: viewModel)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if viewModel.isSelectionMode {
            ToolbarItem(placement: .topBarLeading) {
                Text(MR.strings.librarySelectedCount(viewModel.selectedMangaIds.count))
                    .font(.headline)
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Move to category
                    if viewModel.categories.count > 1 {
                        Button { showCategoryPicker = true } label: {
                            Image(systemName: "folder")
                        }
                    }
                    Button(MR.strings.commonDone) { viewModel.clearSelection() }
                }
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button { showSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel(MR.strings.librarySearchPrompt)

                    Button { showSettings = true } label: {
                        Image(systemName: viewModel.currentFilter.hasActiveFilters
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(MR.strings.libraryFilter)

                    Menu {
                        Button {
                            showCategoryManagement = true
                        } label: {
                            Label(MR.strings.libraryManageCategories, systemImage: "folder.badge.gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel(MR.strings.libraryManageCategories)
                }
            }
        }
    }
}
