import SwiftUI
import MihonDomain
import MihonData

// MARK: - StatisticsScreen

struct StatisticsScreen: View {
    @StateObject private var viewModel = StatisticsViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            } else {
                summarySection
                statusChartSection
                readingActivitySection
            }
        }
        .navigationTitle("Statistics")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
    }

    // MARK: - Summary Cards

    private var summarySection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    icon: "books.vertical.fill",
                    iconColor: .blue,
                    value: "\(viewModel.totalManga)",
                    label: "In Library"
                )
                StatCard(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    value: "\(viewModel.totalChaptersRead)",
                    label: "Chapters Read"
                )
                StatCard(
                    icon: "clock.fill",
                    iconColor: .orange,
                    value: viewModel.totalReadingTimeFormatted,
                    label: "Reading Time"
                )
                StatCard(
                    icon: "star.fill",
                    iconColor: .yellow,
                    value: "\(viewModel.totalBookmarks)",
                    label: "Bookmarks"
                )
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Status Distribution Chart

    private var statusChartSection: some View {
        Section("Manga by Status") {
            if viewModel.statusEntries.isEmpty {
                Text("No manga in library")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.statusEntries) { entry in
                        StatusBar(entry: entry, total: viewModel.totalManga)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Reading Activity

    private var readingActivitySection: some View {
        Section("Reading Activity") {
            StatRow(label: "Started", value: "\(viewModel.startedManga)")
            StatRow(label: "Completed", value: "\(viewModel.completedManga)")
            StatRow(label: "Unread chapters", value: "\(viewModel.totalUnread)")
        }
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - StatusBar

private struct StatusBar: View {
    let entry: StatusEntry
    let total: Int

    private var fraction: Double {
        total > 0 ? Double(entry.count) / Double(total) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(entry.statusName, systemImage: entry.icon)
                    .font(.subheadline)
                    .foregroundStyle(entry.color)
                Spacer()
                Text("\(entry.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(entry.color.opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(entry.color)
                        .frame(width: proxy.size.width * fraction, height: 8)
                        .animation(.easeInOut(duration: 0.6), value: fraction)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - StatRow

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Supporting Types

struct StatusEntry: Identifiable {
    let id: Int64
    let statusName: String
    let icon: String
    let color: Color
    let count: Int
}

// MARK: - ViewModel

@MainActor
final class StatisticsViewModel: ObservableObject {

    @Published var isLoading = true
    @Published var totalManga = 0
    @Published var totalChaptersRead = 0
    @Published var totalBookmarks = 0
    @Published var totalUnread = 0
    @Published var startedManga = 0
    @Published var completedManga = 0
    @Published var statusEntries: [StatusEntry] = []

    // Estimated reading time: assume ~6 minutes per chapter
    private static let minutesPerChapter: Int = 6

    var totalReadingTimeFormatted: String {
        let totalMinutes = totalChaptersRead * Self.minutesPerChapter
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        }
        let hours = totalMinutes / 60
        if hours < 24 {
            return "\(hours)h"
        }
        let days = hours / 24
        return "\(days)d"
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let library = (try? await DIContainer.shared.mangaRepository.getLibraryManga()) ?? []

        totalManga = library.count
        totalChaptersRead = library.reduce(0) { $0 + $1.readCount }
        totalBookmarks = library.reduce(0) { $0 + $1.bookmarkCount }
        totalUnread = library.reduce(0) { $0 + $1.unreadCount }
        startedManga = library.filter { $0.hasStarted }.count

        // Status breakdown
        let statusMap = Dictionary(grouping: library) { $0.manga.status }
        statusEntries = MangaStatus.allCases.compactMap { s in
            let count = statusMap[s.rawValue]?.count ?? 0
            guard count > 0 else { return nil }
            return StatusEntry(id: s.rawValue, statusName: s.displayName, icon: s.icon, color: s.color, count: count)
        }
        .sorted { $0.count > $1.count }

        completedManga = statusMap[MangaStatus.completed.rawValue]?.count ?? 0
    }
}

// MARK: - MangaStatus helper

private enum MangaStatus: Int64, CaseIterable {
    case unknown   = 0
    case ongoing   = 1
    case completed = 2
    case licensed  = 3
    case publishingFinished = 4
    case cancelled = 5
    case onHiatus  = 6

    var displayName: String {
        switch self {
        case .unknown:            return "Unknown"
        case .ongoing:            return "Ongoing"
        case .completed:          return "Completed"
        case .licensed:           return "Licensed"
        case .publishingFinished: return "Publishing Finished"
        case .cancelled:          return "Cancelled"
        case .onHiatus:           return "On Hiatus"
        }
    }

    var icon: String {
        switch self {
        case .unknown:            return "questionmark.circle"
        case .ongoing:            return "arrow.clockwise.circle"
        case .completed:          return "checkmark.circle"
        case .licensed:           return "lock.circle"
        case .publishingFinished: return "flag.checkered.circle"
        case .cancelled:          return "xmark.circle"
        case .onHiatus:           return "pause.circle"
        }
    }

    var color: Color {
        switch self {
        case .unknown:            return .gray
        case .ongoing:            return .blue
        case .completed:          return .green
        case .licensed:           return .orange
        case .publishingFinished: return .teal
        case .cancelled:          return .red
        case .onHiatus:           return .yellow
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        StatisticsScreen()
    }
}
