import SwiftUI
import ShinsouUI
import ShinsouI18n
import ShinsouData

struct MainView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPhone: Bottom TabView
    private var iPhoneLayout: some View {
        TabView {
            LibraryScreen(viewModel: LibraryViewModel(
                mangaRepository: DIContainer.shared.mangaRepository,
                categoryRepository: DIContainer.shared.categoryRepository,
                preferences: DIContainer.shared.preferences
            ))
                .tabItem {
                    Label(MR.strings.tabLibrary, systemImage: "books.vertical")
                }

            UpdatesScreen()
                .tabItem {
                    Label(MR.strings.tabUpdates, systemImage: "bell")
                }

            HistoryScreen()
                .tabItem {
                    Label(MR.strings.tabHistory, systemImage: "clock")
                }

            BrowseScreen()
                .tabItem {
                    Label(MR.strings.tabBrowse, systemImage: "globe")
                }

            MoreScreen()
                .tabItem {
                    Label(MR.strings.tabMore, systemImage: "ellipsis")
                }
        }
    }

    // MARK: - iPad: NavigationSplitView (增強版，實作於 MainView+iPad.swift)
    // iPadLayout 由 MainView+iPad.swift extension 提供
    // 此處保留原始 private 計算屬性作為轉接，實際邏輯已移至 extension

    enum Tab: Hashable {
        case library, updates, history, browse, more
    }
}

