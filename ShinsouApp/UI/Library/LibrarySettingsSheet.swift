import SwiftUI
import ShinsouDomain
import ShinsouI18n

struct LibrarySettingsSheet: View {
    @ObservedObject var viewModel: LibraryViewModel
    @State private var selectedTab = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Settings", selection: $selectedTab) {
                    Text(MR.strings.libraryFilter).tag(0)
                    Text(MR.strings.librarySort).tag(1)
                    Text(MR.strings.libraryDisplay).tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                // Tab content
                Group {
                    switch selectedTab {
                    case 0: filterTab
                    case 1: sortTab
                    case 2: displayTab
                    default: EmptyView()
                    }
                }

                Spacer()
            }
            .navigationTitle(MR.strings.librarySettings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(MR.strings.commonDone) { dismiss() }
                }
            }
        }
    }

    // MARK: - Filter Tab

    private var filterTab: some View {
        List {
            Section {
                filterRow(MR.strings.libraryDownloaded, state: viewModel.currentFilter.downloaded) { newState in
                    viewModel.currentFilter.downloaded = newState
                    viewModel.updateFilter(viewModel.currentFilter)
                }
                filterRow(MR.strings.libraryUnread, state: viewModel.currentFilter.unread) { newState in
                    viewModel.currentFilter.unread = newState
                    viewModel.updateFilter(viewModel.currentFilter)
                }
                filterRow(MR.strings.libraryStarted, state: viewModel.currentFilter.started) { newState in
                    viewModel.currentFilter.started = newState
                    viewModel.updateFilter(viewModel.currentFilter)
                }
                filterRow(MR.strings.libraryBookmarked, state: viewModel.currentFilter.bookmarked) { newState in
                    viewModel.currentFilter.bookmarked = newState
                    viewModel.updateFilter(viewModel.currentFilter)
                }
                filterRow(MR.strings.libraryCompleted, state: viewModel.currentFilter.completed) { newState in
                    viewModel.currentFilter.completed = newState
                    viewModel.updateFilter(viewModel.currentFilter)
                }
            }

            Section(MR.strings.libraryTracking) {
                ForEach(TrackerID.all, id: \.id) { tracker in
                    let state = viewModel.currentFilter.trackerFilter(for: tracker.id)
                    filterRow(tracker.name, state: state) { newState in
                        let updated = viewModel.currentFilter.withTrackerFilter(newState, for: tracker.id)
                        viewModel.updateFilter(updated)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func filterRow(
        _ title: String,
        state: LibraryFilter.TriState,
        onToggle: @escaping (LibraryFilter.TriState) -> Void
    ) -> some View {
        Button {
            onToggle(state.next())
        } label: {
            HStack {
                Image(systemName: triStateIcon(state))
                    .foregroundStyle(triStateColor(state))
                    .frame(width: 24)

                Text(title)
                    .foregroundStyle(.primary)

                Spacer()
            }
        }
    }

    private func triStateIcon(_ state: LibraryFilter.TriState) -> String {
        switch state {
        case .disabled: return "circle"
        case .include: return "checkmark.circle.fill"
        case .exclude: return "minus.circle.fill"
        }
    }

    private func triStateColor(_ state: LibraryFilter.TriState) -> Color {
        switch state {
        case .disabled: return .secondary
        case .include: return Color.accentColor
        case .exclude: return .red
        }
    }

    // MARK: - Sort Tab

    private var sortTab: some View {
        List {
            ForEach(LibrarySort.SortType.allCases, id: \.rawValue) { sortType in
                Button {
                    if viewModel.currentSort.type == sortType {
                        if sortType == .random {
                            // Tapping the active random sort reshuffles
                            viewModel.reshuffleRandom()
                        } else {
                            let newDir = viewModel.currentSort.direction.toggled()
                            viewModel.updateSort(LibrarySort(type: sortType, direction: newDir))
                        }
                    } else {
                        let seed: UInt64 = sortType == .random
                            ? UInt64.random(in: 0...UInt64.max)
                            : 0
                        viewModel.updateSort(LibrarySort(type: sortType, direction: .ascending, randomSeed: seed))
                    }
                } label: {
                    HStack {
                        Text(sortType.displayName)
                            .foregroundStyle(.primary)

                        Spacer()

                        if viewModel.currentSort.type == sortType {
                            if sortType == .random {
                                Image(systemName: "shuffle")
                                    .foregroundStyle(Color.accentColor)
                            } else {
                                Image(systemName: viewModel.currentSort.direction.isAscending ? "arrow.up" : "arrow.down")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }

            // Dedicated Reshuffle button — visible only when random sort is active.
            if viewModel.currentSort.type == .random {
                Button {
                    viewModel.reshuffleRandom()
                } label: {
                    HStack {
                        Image(systemName: "shuffle.circle")
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 24)
                        Text(MR.strings.libraryReshuffle)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Display Tab

    private var displayTab: some View {
        List {
            Section(MR.strings.libraryDisplayMode) {
                displayModeRow(MR.strings.libraryCompactGrid, icon: "square.grid.2x2", mode: .compactGrid)
                displayModeRow(MR.strings.libraryComfortableGrid, icon: "square.grid.2x2.fill", mode: .comfortableGrid)
                displayModeRow(MR.strings.libraryCoverOnlyGrid, icon: "rectangle.grid.2x2", mode: .coverOnlyGrid)
                displayModeRow(MR.strings.libraryList, icon: "list.bullet", mode: .list)
            }

            Section(MR.strings.libraryBadges) {
                Toggle(MR.strings.libraryUnreadCount, isOn: .constant(true))
                Toggle(MR.strings.libraryDownloadCount, isOn: .constant(true))
                Toggle(MR.strings.libraryLocalSource, isOn: .constant(true))
            }

            Section(MR.strings.libraryCategoryTabs) {
                Toggle(MR.strings.libraryShowCategoryTabs, isOn: .constant(true))
                Toggle(MR.strings.libraryShowMangaCount, isOn: .constant(true))
            }
        }
        .listStyle(.insetGrouped)
    }

    private func displayModeRow(_ title: String, icon: String, mode: LibraryDisplayMode) -> some View {
        Button {
            viewModel.updateDisplayMode(mode)
        } label: {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if viewModel.displayMode == mode {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}
