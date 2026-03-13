import SwiftUI
import Combine
import MihonI18n

// MARK: - BrowseScreen

/// Top-level browse container with three tabs matching the Android layout:
/// 來源 (Sources) / 擴充套件 (Extensions) / 遷移 (Migration)
struct BrowseScreen: View {
    @State private var selectedTab: BrowseTab = .sources
    @ObservedObject private var extensionManager = ExtensionManager.shared

    enum BrowseTab: Int, CaseIterable {
        case sources
        case extensions
        case migration
    }

    /// Number of extensions with available updates (shown as badge on Extensions tab).
    private var updateCount: Int {
        extensionManager.extensions.filter {
            if case .hasUpdate = $0.state { return true }
            return false
        }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                tabPicker
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                // Tab content
                tabContent
            }
            .navigationTitle(MR.strings.tabBrowse)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    toolbarItems
                }
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(BrowseTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
    }

    private func tabButton(_ tab: BrowseTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text(tabTitle(tab))
                        .font(.subheadline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)

                    // Badge for extension updates
                    if tab == .extensions && updateCount > 0 {
                        Text("\(updateCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                .foregroundStyle(selectedTab == tab ? Color.accentColor : .secondary)

                // Underline indicator
                Rectangle()
                    .fill(selectedTab == tab ? Color.accentColor : .clear)
                    .frame(height: 2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func tabTitle(_ tab: BrowseTab) -> String {
        switch tab {
        case .sources: return MR.strings.browseSources
        case .extensions: return MR.strings.browseExtensions
        case .migration: return MR.strings.browseMigration
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .sources:
            SourcesTabContent()
        case .extensions:
            ExtensionListContent()
        case .migration:
            MigrationSourcesScreen()
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbarItems: some View {
        switch selectedTab {
        case .sources:
            HStack(spacing: 16) {
                NavigationLink {
                    GlobalSearchScreen()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                LanguageFilterButton()
            }
        case .extensions:
            LanguageFilterButton()
        case .migration:
            EmptyView()
        }
    }
}

// MARK: - Source Filter Button

/// Extracted to separate struct so it can manage its own state.
private struct LanguageFilterButton: View {
    @ObservedObject private var langStore = LanguageFilterStore.shared
    @ObservedObject private var sourceManager = SourceManager.shared
    @ObservedObject private var extensionManager = ExtensionManager.shared
    @State private var showLanguageFilter = false

    /// 統一語言清單：來源 + 擴充套件的聯集，確保兩個 tab 篩選一致。
    private var availableLanguages: [String] {
        let sourceLangs = sourceManager.catalogueSources.map(\.lang)
        let extensionLangs = extensionManager.extensions.map(\.lang)
        return Array(Set(sourceLangs + extensionLangs))
    }

    var body: some View {
        Button {
            showLanguageFilter = true
        } label: {
            Image(systemName: langStore.isAllEnabled
                  ? "line.3.horizontal.decrease.circle"
                  : "line.3.horizontal.decrease.circle.fill")
        }
        .sheet(isPresented: $showLanguageFilter) {
            LanguageFilterSheet(
                langStore: langStore,
                availableLanguages: availableLanguages
            )
        }
    }
}
