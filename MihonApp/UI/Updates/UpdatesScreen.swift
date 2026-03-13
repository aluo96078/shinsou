import SwiftUI
import MihonDomain
import MihonData
import MihonUI
import NukeUI

// MARK: - UpdatesScreen

struct UpdatesScreen: View {
    @StateObject private var viewModel = UpdatesViewModel()
    @State private var selectedTab: UpdatesTab = .recent
    @State private var readerDestination: ReaderDestination? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Selector: Recent / Upcoming
                Picker("", selection: $selectedTab) {
                    ForEach(UpdatesTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                if selectedTab == .recent {
                    recentView
                } else {
                    UpcomingScreen()
                }
            }
            .navigationTitle("Updates")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Top-right: Refresh or Cancel Selection
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isSelectionMode {
                        Button("Cancel") {
                            viewModel.exitSelectionMode()
                        }
                    } else {
                        Button {
                            Task { await viewModel.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.isLoading)
                    }
                }

                // Top-left: Select All / Deselect All (in selection mode)
                ToolbarItem(placement: .topBarLeading) {
                    if viewModel.isSelectionMode {
                        Button(viewModel.isAllSelected ? "Deselect All" : "Select All") {
                            viewModel.toggleSelectAll()
                        }
                    }
                }
            }
            // Bottom Batch Toolbar
            .safeAreaInset(edge: .bottom) {
                if viewModel.isSelectionMode {
                    batchToolbar
                }
            }
        }
        .fullScreenCover(item: $readerDestination) { dest in
            ReaderContainerView(mangaId: dest.mangaId, chapterId: dest.chapterId)
        }
        .task {
            await viewModel.loadUpdates()
        }
    }

    // MARK: - Recent View

    @ViewBuilder
    private var recentView: some View {
        if viewModel.isLoading {
            LoadingView()
        } else if viewModel.updates.isEmpty {
            EmptyStateView(icon: "bell", message: "No recent updates")
        } else {
            updatesList
        }
    }

    // MARK: - Updates List

    private var updatesList: some View {
        List {
            ForEach(viewModel.groupedUpdates, id: \.key) { group in
                Section(group.key) {
                    ForEach(group.value) { item in
                        UpdateRow(
                            item: item,
                            isSelectionMode: viewModel.isSelectionMode,
                            isSelected: viewModel.selectedIds.contains(item.id)
                        ) {
                            viewModel.toggleSelection(item)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if viewModel.isSelectionMode {
                                viewModel.toggleSelection(item)
                            } else {
                                readerDestination = ReaderDestination(
                                    mangaId: item.manga.id,
                                    chapterId: item.chapter.id
                                )
                            }
                        }
                        .onLongPressGesture {
                            if !viewModel.isSelectionMode {
                                viewModel.enterSelectionMode(initialItem: item)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, viewModel.isSelectionMode ? .constant(.active) : .constant(.inactive))
    }

    // MARK: - Batch Toolbar

    private var batchToolbar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                BatchActionButton(icon: "checkmark.circle", label: "Read") {
                    Task { await viewModel.markSelectedRead(true) }
                }
                BatchActionButton(icon: "circle", label: "Unread") {
                    Task { await viewModel.markSelectedRead(false) }
                }
                BatchActionButton(icon: "arrow.down.circle", label: "Download") {
                    viewModel.downloadSelected()
                }
                BatchActionButton(icon: "trash", label: "Delete") {
                    viewModel.deleteSelected()
                }
                BatchActionButton(icon: "bookmark", label: "Bookmark") {
                    Task { await viewModel.toggleBookmarkSelected() }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.regularMaterial)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - UpdatesTab

enum UpdatesTab: String, CaseIterable, Identifiable {
    case recent, upcoming

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent:   return "Recent"
        case .upcoming: return "Upcoming"
        }
    }
}

// MARK: - BatchActionButton

private struct BatchActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - UpdateRow

private struct UpdateRow: View {
    let item: UpdateItem
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Selection Indicator
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
                    .onTapGesture { onTap() }
            }

            // Cover
            if let urlString = item.manga.thumbnailUrl, let imageUrl = URL(string: urlString) {
                LazyImage(url: imageUrl) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                }
                .frame(width: 48, height: 64)
                .clipped()
                .cornerRadius(4)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 48, height: 64)
                    .cornerRadius(4)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.manga.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(item.chapter.name)
                    .font(.caption)
                    .foregroundStyle(item.chapter.read ? .secondary : .primary)
                    .lineLimit(1)

                if let scanlator = item.chapter.scanlator, !scanlator.isEmpty {
                    Text(scanlator)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if !isSelectionMode {
                Button {
                    DownloadManager.shared.enqueue(manga: item.manga, chapters: [item.chapter])
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
    }
}

// MARK: - UpdatesViewModel

@MainActor
final class UpdatesViewModel: ObservableObject {

    // MARK: Data
    @Published var updates: [UpdateItem] = []
    @Published var isLoading = true

    // MARK: Selection State
    @Published var isSelectionMode = false
    @Published var selectedIds: Set<Int64> = []

    var isAllSelected: Bool {
        !updates.isEmpty && selectedIds.count == updates.count
    }

    var selectedItems: [UpdateItem] {
        updates.filter { selectedIds.contains($0.id) }
    }

    // MARK: Grouped Updates
    var groupedUpdates: [(key: String, value: [UpdateItem])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let grouped = Dictionary(grouping: updates) { item -> String in
            let date = Date(timeIntervalSince1970: Double(item.chapter.dateFetch) / 1000.0)
            return formatter.string(from: date)
        }
        return grouped.sorted { a, b in
            guard let aFirst = a.value.first, let bFirst = b.value.first else { return false }
            return aFirst.chapter.dateFetch > bFirst.chapter.dateFetch
        }
    }

    // MARK: Dependencies
    private let updatesRepository: UpdatesRepository
    private let chapterRepository: ChapterRepository

    init() {
        self.updatesRepository = DIContainer.shared.updatesRepository
        self.chapterRepository = DIContainer.shared.chapterRepository
    }

    // MARK: - Load / Refresh

    func loadUpdates() async {
        isLoading = true
        do {
            updates = try await updatesRepository.getRecentUpdates(limit: 100)
        } catch {
            print("Error loading updates: \(error)")
        }
        isLoading = false
    }

    func refresh() async {
        await loadUpdates()
    }

    // MARK: - Selection

    func enterSelectionMode(initialItem: UpdateItem) {
        isSelectionMode = true
        selectedIds = [initialItem.id]
    }

    func exitSelectionMode() {
        isSelectionMode = false
        selectedIds = []
    }

    func toggleSelection(_ item: UpdateItem) {
        if selectedIds.contains(item.id) {
            selectedIds.remove(item.id)
        } else {
            selectedIds.insert(item.id)
        }
    }

    func toggleSelectAll() {
        if isAllSelected {
            selectedIds = []
        } else {
            selectedIds = Set(updates.map(\.id))
        }
    }

    // MARK: - Batch Actions

    func markSelectedRead(_ read: Bool) async {
        for item in selectedItems {
            try? await chapterRepository.updatePartial(
                id: item.chapter.id,
                read: read,
                bookmark: nil,
                lastPageRead: nil
            )
        }
        await loadUpdates()
        exitSelectionMode()
    }

    func downloadSelected() {
        // Group by manga to use enqueue(manga:chapters:)
        let byManga: [Int64: (Manga, [Chapter])] = selectedItems.reduce(into: [:]) { acc, item in
            if var existing = acc[item.manga.id] {
                existing.1.append(item.chapter)
                acc[item.manga.id] = existing
            } else {
                acc[item.manga.id] = (item.manga, [item.chapter])
            }
        }
        for (_, pair) in byManga {
            DownloadManager.shared.enqueue(manga: pair.0, chapters: pair.1)
        }
        exitSelectionMode()
    }

    func deleteSelected() {
        let ids = selectedItems.map { "\($0.manga.id)_\($0.chapter.id)" }
        for id in ids {
            DownloadManager.shared.remove(itemId: id)
        }
        exitSelectionMode()
    }

    func toggleBookmarkSelected() async {
        for item in selectedItems {
            try? await chapterRepository.updatePartial(
                id: item.chapter.id,
                read: nil,
                bookmark: !item.chapter.bookmark,
                lastPageRead: nil
            )
        }
        await loadUpdates()
        exitSelectionMode()
    }
}
