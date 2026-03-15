import SwiftUI
import ShinsouDomain
import ShinsouUI
import ShinsouI18n
import Nuke
import NukeUI

extension LibraryGridView {

    // MARK: - iPad 欄位計算

    /// 根據可用寬度動態計算 iPad 的格子欄數
    /// - 寬度 < 600pt：5 欄
    /// - 600–768pt：6 欄
    /// - 768–1024pt：7 欄
    /// - 1024pt 以上：8 欄
    func iPadColumnCount(for width: CGFloat) -> Int {
        switch width {
        case ..<600:    return 5
        case 600..<768: return 6
        case 768..<1024: return 7
        default:        return 8
        }
    }

    /// iPad 使用固定欄數的 GridItem 陣列（依寬度動態決定）
    func iPadColumns(for width: CGFloat) -> [GridItem] {
        let count = iPadColumnCount(for: width)
        return Array(
            repeating: GridItem(.flexible(), spacing: 8),
            count: count
        )
    }

    // MARK: - iPad 增強版網格視圖

    /// iPad 專用的網格佈局，提供更多欄位及右鍵選單
    @ViewBuilder
    var iPadEnhancedBody: some View {
        GeometryReader { geo in
            ScrollView {
                LazyVGrid(columns: iPadColumns(for: geo.size.width), spacing: 10) {
                    ForEach(items) { item in
                        if viewModel.isSelectionMode {
                            Button {
                                viewModel.toggleSelection(item.id)
                            } label: {
                                gridItemView(for: item, width: geo.size.width)
                            }
                            .buttonStyle(.plain)
                            .overlay { iPadSelectionOverlay(for: item.id) }
                        } else {
                            NavigationLink(value: item.libraryManga.manga.id) {
                                gridItemView(for: item, width: geo.size.width)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in viewModel.toggleSelection(item.id) }
                            )
                            // iPad 增強版 Context Menu
                            .contextMenu {
                                iPadContextMenu(for: item)
                            } preview: {
                                iPadContextMenuPreview(for: item)
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
        }
        .navigationDestination(for: Int64.self) { mangaId in
            MangaDetailScreen(mangaId: mangaId)
        }
    }

    // MARK: - 格子項目視圖（依寬度縮放）

    @ViewBuilder
    private func gridItemView(for item: LibraryItem, width: CGFloat) -> some View {
        switch mode {
        case .compact:
            iPadCompactItem(item: item)
        case .comfortable:
            iPadComfortableItem(item: item)
        case .coverOnly:
            iPadCoverOnlyItem(item: item)
        }
    }

    // MARK: - iPad Context Menu

    @ViewBuilder
    private func iPadContextMenu(for item: LibraryItem) -> some View {
        // 閱讀操作
        Section {
            Button {
                // TODO: 開始閱讀
            } label: {
                Label(MR.strings.libraryResumeReading, systemImage: "book")
            }

            Button {
                // TODO: 從頭開始
            } label: {
                Label(MR.strings.libraryReadFromStart, systemImage: "book.fill")
            }
        }

        // 收藏與追蹤
        Section {
            Button {
                Task { await toggleFavoriteForItem(item) }
            } label: {
                Label(
                    item.libraryManga.manga.favorite ? MR.strings.libraryRemoveFromLibrary : MR.strings.mangaAddToLibrary,
                    systemImage: item.libraryManga.manga.favorite ? "heart.slash" : "heart"
                )
            }

            Button {
                // TODO: 開啟追蹤 sheet
            } label: {
                Label(MR.strings.libraryTracking, systemImage: "arrow.triangle.2.circlepath")
            }
        }

        // 章節管理
        Section {
            Button {
                // TODO: 標記所有章節已讀
            } label: {
                Label(MR.strings.libraryMarkAllRead, systemImage: "eye")
            }

            Button {
                // TODO: 標記所有章節未讀
            } label: {
                Label(MR.strings.libraryMarkAllUnread, systemImage: "eye.slash")
            }
        }

        // 分類管理
        Section {
            Button {
                // TODO: 移動分類
            } label: {
                Label(MR.strings.libraryMoveToCategory, systemImage: "folder")
            }
        }

        // 分享與刪除
        Section {
            Button {
                // TODO: 分享
            } label: {
                Label(MR.strings.actionShare, systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                // TODO: 從書庫移除
            } label: {
                Label(MR.strings.libraryRemoveFromLibrary, systemImage: "trash")
            }
        }
    }

    /// Context Menu 的預覽縮圖
    @ViewBuilder
    private func iPadContextMenuPreview(for item: LibraryItem) -> some View {
        VStack(spacing: 0) {
            // 封面圖片
            Group {
                if let url = item.libraryManga.manga.thumbnailUrl,
                   let imageUrl = URL(string: url) {
                    LazyImage(request: .proxied(url: imageUrl)) { state in
                        if let image = state.image {
                            image.resizable().scaledToFill()
                        } else {
                            coverPreviewPlaceholder
                        }
                    }
                } else {
                    coverPreviewPlaceholder
                }
            }
            .frame(width: 200, height: 280)
            .clipped()

            // 標題
            Text(item.libraryManga.manga.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(width: 200)
                .background(Color(.systemBackground))
        }
        .cornerRadius(12)
        .shadow(radius: 4)
    }

    private var coverPreviewPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "book.closed")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - 選取疊加層（iPad 版）

    /// iPad 版的選取狀態覆蓋層，複用與主體相同的視覺邏輯
    func iPadSelectionOverlay(for id: Int64) -> some View {
        ZStack(alignment: .bottomTrailing) {
            Color.black.opacity(viewModel.selectedMangaIds.contains(id) ? 0.3 : 0)
                .cornerRadius(8)

            if viewModel.selectedMangaIds.contains(id) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, Color.accentColor)
                    .padding(6)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 輔助方法

    private func toggleFavoriteForItem(_ item: LibraryItem) async {
        // LibraryGridView 本身不持有 MangaRepository
        // 此處透過 viewModel 間接觸發（未來可擴充）
        // TODO: 實作收藏切換邏輯
        _ = item
    }
}

// MARK: - iPad 格子樣式

/// iPad Compact 樣式：封面上疊加標題，badge 在右上角
private struct iPadCompactItem: View {
    let item: LibraryItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            coverImage

            // 底部漸層
            VStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 56)
            }

            // 標題
            VStack(alignment: .leading) {
                Spacer()
                Text(item.libraryManga.manga.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(5)
            }

            // Badge
            badgeOverlay
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fill)
        .clipped()
        .cornerRadius(8)
    }

    private var coverImage: some View {
        Group {
            if let url = item.libraryManga.manga.thumbnailUrl,
               let imageUrl = URL(string: url) {
                LazyImage(request: .proxied(url: imageUrl)) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else { placeholder }
                }
            } else { placeholder }
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "book.closed").foregroundStyle(.secondary)
            }
    }

    private var badgeOverlay: some View {
        VStack {
            HStack(spacing: 3) {
                if item.unreadCount > 0 {
                    BadgeView(count: Int(item.unreadCount), color: Color.accentColor)
                }
                if item.downloadCount > 0 {
                    BadgeView(count: Int(item.downloadCount), color: .green)
                }
                if item.isLocal {
                    Image(systemName: "internaldrive")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(.gray, in: Circle())
                }
                Spacer()
            }
            .padding(3)
            Spacer()
        }
    }
}

/// iPad Comfortable 樣式：封面下方顯示標題
private struct iPadComfortableItem: View {
    let item: LibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ZStack(alignment: .topLeading) {
                coverImage
                    .aspectRatio(2.0 / 3.0, contentMode: .fill)
                    .clipped()
                    .cornerRadius(8)

                HStack(spacing: 3) {
                    if item.unreadCount > 0 {
                        BadgeView(count: Int(item.unreadCount), color: Color.accentColor)
                    }
                    if item.downloadCount > 0 {
                        BadgeView(count: Int(item.downloadCount), color: .green)
                    }
                    if item.isLocal {
                        Image(systemName: "internaldrive")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(.gray, in: Circle())
                    }
                }
                .padding(3)
            }

            Text(item.libraryManga.manga.title)
                .font(.caption2)
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
    }

    private var coverImage: some View {
        Group {
            if let url = item.libraryManga.manga.thumbnailUrl,
               let imageUrl = URL(string: url) {
                LazyImage(request: .proxied(url: imageUrl)) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else { placeholder }
                }
            } else { placeholder }
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "book.closed").foregroundStyle(.secondary)
            }
    }
}

/// iPad Cover Only 樣式：純封面，無文字
private struct iPadCoverOnlyItem: View {
    let item: LibraryItem

    var body: some View {
        ZStack(alignment: .topLeading) {
            coverImage

            HStack(spacing: 3) {
                if item.unreadCount > 0 {
                    BadgeView(count: Int(item.unreadCount), color: Color.accentColor)
                }
                if item.downloadCount > 0 {
                    BadgeView(count: Int(item.downloadCount), color: .green)
                }
                if item.isLocal {
                    Image(systemName: "internaldrive")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(.gray, in: Circle())
                }
            }
            .padding(3)
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fill)
        .clipped()
        .cornerRadius(8)
    }

    private var coverImage: some View {
        Group {
            if let url = item.libraryManga.manga.thumbnailUrl,
               let imageUrl = URL(string: url) {
                LazyImage(request: .proxied(url: imageUrl)) { state in
                    if let image = state.image {
                        image.resizable().scaledToFill()
                    } else { placeholder }
                }
            } else { placeholder }
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "book.closed").foregroundStyle(.secondary)
            }
    }
}
