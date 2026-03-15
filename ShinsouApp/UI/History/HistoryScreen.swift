import SwiftUI
import ShinsouDomain
import ShinsouData
import ShinsouUI
import ShinsouI18n
import Nuke
import NukeUI

struct HistoryScreen: View {
    @StateObject private var viewModel = HistoryViewModel()
    @State private var readerDestination: ReaderDestination? = nil

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else if viewModel.historyItems.isEmpty {
                    EmptyStateView(icon: "clock", message: MR.strings.historyNoHistory)
                } else {
                    historyList
                }
            }
            .navigationTitle(MR.strings.historyTitle)
            .searchable(text: $viewModel.searchQuery, prompt: MR.strings.historySearch)
            .onChange(of: viewModel.searchQuery) { _ in
                Task { await viewModel.search() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            Task { await viewModel.clearAllHistory() }
                        } label: {
                            Label(MR.strings.historyClearAll, systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .fullScreenCover(item: $readerDestination) { dest in
                ReaderContainerView(mangaId: dest.mangaId, chapterId: dest.chapterId)
            }
        }
        .task {
            await viewModel.loadHistory()
        }
    }

    private var historyList: some View {
        List {
            ForEach(viewModel.groupedHistory, id: \.key) { group in
                Section(group.key) {
                    ForEach(group.value) { item in
                        HistoryRow(item: item) {
                            readerDestination = ReaderDestination(
                                mangaId: item.manga.id,
                                chapterId: item.chapter.id
                            )
                        }
                        .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteHistoryItem(item) }
                                } label: {
                                    Label(MR.strings.historyRemove, systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

private struct HistoryRow: View {
    let item: HistoryItem
    let onResume: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let urlString = item.manga.thumbnailUrl, let imageUrl = URL(string: urlString) {
                LazyImage(request: .proxied(url: imageUrl)) { state in
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

            VStack(alignment: .leading, spacing: 4) {
                Text(item.manga.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(item.chapter.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(formatDate(item.lastRead))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                onResume()
            } label: {
                Image(systemName: "play.circle")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatDate(_ epochMillis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(epochMillis) / 1000.0)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var historyItems: [HistoryItem] = []
    @Published var isLoading = true
    @Published var searchQuery = ""

    var groupedHistory: [(key: String, value: [HistoryItem])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let grouped = Dictionary(grouping: historyItems) { item -> String in
            let date = Date(timeIntervalSince1970: Double(item.lastRead) / 1000.0)
            return formatter.string(from: date)
        }
        return grouped.sorted { a, b in
            guard let aFirst = a.value.first, let bFirst = b.value.first else { return false }
            return aFirst.lastRead > bFirst.lastRead
        }
    }

    private let historyRepository: HistoryRepository

    init() {
        self.historyRepository = DIContainer.shared.historyRepository
    }

    func loadHistory() async {
        isLoading = true
        do {
            historyItems = try await historyRepository.getHistory(query: "")
        } catch {
            print("Error loading history: \(error)")
        }
        isLoading = false
    }

    func search() async {
        do {
            historyItems = try await historyRepository.getHistory(query: searchQuery)
        } catch {
            print("Error searching history: \(error)")
        }
    }

    func deleteHistoryItem(_ item: HistoryItem) async {
        do {
            try await historyRepository.deleteByMangaId(mangaId: item.manga.id)
            await loadHistory()
        } catch {
            print("Error deleting history: \(error)")
        }
    }

    func clearAllHistory() async {
        do {
            try await historyRepository.deleteAll()
            historyItems = []
        } catch {
            print("Error clearing history: \(error)")
        }
    }
}
