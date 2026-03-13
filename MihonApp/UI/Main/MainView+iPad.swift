import SwiftUI
import MihonUI
import MihonI18n
import MihonData

extension MainView {

    // MARK: - 增強版 iPad NavigationSplitView

    /// 使用 @State 追蹤選中的側欄項目，並根據選取狀態切換詳細內容
    var iPadLayout: some View {
        iPadSplitView
    }

    private var iPadSplitView: some View {
        _IPadSplitViewContainer()
    }
}

// MARK: - iPad 分割視圖容器

/// 獨立的容器 View，以持有 @State 並管理側欄選取與詳細頁面路由
private struct _IPadSplitViewContainer: View {
    @State private var selectedTab: MainView.Tab? = .library

    // 每個 tab 使用獨立的 ViewModel，確保狀態不互相干擾
    @StateObject private var libraryViewModel = LibraryViewModel(
        mangaRepository: DIContainer.shared.mangaRepository,
        categoryRepository: DIContainer.shared.categoryRepository,
        preferences: DIContainer.shared.preferences
    )

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
    }

    // MARK: - 側欄

    private var sidebar: some View {
        List(selection: $selectedTab) {
            sidebarItem(tab: .library, icon: "books.vertical", label: MR.strings.tabLibrary)
            sidebarItem(tab: .updates, icon: "bell", label: MR.strings.tabUpdates)
            sidebarItem(tab: .history, icon: "clock", label: MR.strings.tabHistory)
            sidebarItem(tab: .browse, icon: "globe", label: MR.strings.tabBrowse)

            Divider()

            sidebarItem(tab: .more, icon: "ellipsis", label: MR.strings.tabMore)
        }
        .navigationTitle("Shinsou")
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        .listStyle(.sidebar)
    }

    private func sidebarItem(tab: MainView.Tab, icon: String, label: String) -> some View {
        Label(label, systemImage: icon)
            .tag(tab)
            .padding(.vertical, 2)
    }

    // MARK: - 詳細內容路由

    @ViewBuilder
    private var detailContent: some View {
        switch selectedTab {
        case .library:
            LibraryScreen(viewModel: libraryViewModel)

        case .updates:
            UpdatesScreen()

        case .history:
            HistoryScreen()

        case .browse:
            BrowseScreen()

        case .more:
            MoreScreen()

        case .none:
            Text("Select a tab")
                .foregroundStyle(.secondary)
        }
    }
}
