import SwiftUI
import ShinsouDomain
import ShinsouUI
import Nuke
import NukeUI

enum LibraryGridMode {
    case compact
    case comfortable
    case coverOnly
}

struct LibraryGridView: View {
    let items: [LibraryItem]
    let mode: LibraryGridMode
    @ObservedObject var viewModel: LibraryViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        let minWidth: CGFloat = sizeClass == .regular ? 140 : 110
        return [GridItem(.adaptive(minimum: minWidth), spacing: 8)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    if viewModel.isSelectionMode {
                        // In selection mode: tap toggles selection, no navigation
                        Button {
                            viewModel.toggleSelection(item.id)
                        } label: {
                            gridItemView(for: item)
                        }
                        .buttonStyle(.plain)
                        .overlay { selectionOverlay(for: item.id) }
                    } else {
                        // Normal mode: tap navigates, long press / context menu for selection
                        NavigationLink(value: item.libraryManga.manga.id) {
                            gridItemView(for: item)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in viewModel.toggleSelection(item.id) }
                        )
                        .contextMenu {
                            Button {
                                viewModel.toggleSelection(item.id)
                            } label: {
                                Label("Select", systemImage: "checkmark.circle")
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func gridItemView(for item: LibraryItem) -> some View {
        switch mode {
        case .compact:
            CompactGridItem(item: item)
        case .comfortable:
            ComfortableGridItem(item: item)
        case .coverOnly:
            CoverOnlyGridItem(item: item)
        }
    }

    private func selectionOverlay(for id: Int64) -> some View {
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
}

// MARK: - Source Image Helper

/// Build an ImageRequest with source-specific headers (Referer, Cookie, etc.)
@MainActor
private func sourceImageRequest(url: URL, sourceId: Int64) -> ImageRequest {
    var headers: [String: String] = [:]
    if let jsProxy = SourceManager.shared.getCatalogueSource(id: sourceId) as? JSSourceProxy {
        headers = jsProxy.sourceHeaders
    }
    if let urlRequest = NetworkHelper.shared.imageURLRequest(for: url.absoluteString, headers: headers) {
        return ImageRequest(urlRequest: urlRequest)
    }
    return ImageRequest(url: url)
}

// MARK: - Compact Grid Item (title overlaid on cover)

private struct CompactGridItem: View {
    let item: LibraryItem

    var body: some View {
        Color(.secondarySystemBackground)
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                ZStack(alignment: .bottomLeading) {
                    coverImage

                    // Gradient overlay
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .center,
                        endPoint: .bottom
                    )

                    // Title
                    VStack(alignment: .leading) {
                        Spacer()
                        Text(item.libraryManga.manga.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .padding(6)
                    }

                    // Badges (top-leading)
                    badgeOverlay
                }
            }
            .clipped()
            .cornerRadius(8)
    }

    private var coverImage: some View {
        Group {
            if let url = item.libraryManga.manga.thumbnailUrl,
               let imageUrl = URL(string: url) {
                LazyImage(request: sourceImageRequest(url: imageUrl, sourceId: item.libraryManga.manga.source)) { state in
                    if let image = state.image {
                        image.resizable().scaledToFit()
                    } else {
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "book.closed")
                    .foregroundStyle(.secondary)
            }
    }

    private var badgeOverlay: some View {
        VStack {
            HStack(spacing: 4) {
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
                        .padding(4)
                        .background(.gray, in: Circle())
                }
                Spacer()
            }
            .padding(4)
            Spacer()
        }
    }
}

// MARK: - Comfortable Grid Item (title below cover)

private struct ComfortableGridItem: View {
    let item: LibraryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                Color(.secondarySystemBackground)
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay {
                        coverImage
                    }
                    .clipped()
                    .cornerRadius(8)

                HStack(spacing: 4) {
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
                            .padding(4)
                            .background(.gray, in: Circle())
                    }
                }
                .padding(4)
            }

            Text(item.libraryManga.manga.title)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
    }

    private var coverImage: some View {
        Group {
            if let url = item.libraryManga.manga.thumbnailUrl,
               let imageUrl = URL(string: url) {
                LazyImage(request: sourceImageRequest(url: imageUrl, sourceId: item.libraryManga.manga.source)) { state in
                    if let image = state.image {
                        image.resizable().scaledToFit()
                    } else {
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "book.closed")
                    .foregroundStyle(.secondary)
            }
    }
}

// MARK: - Cover Only Grid Item

private struct CoverOnlyGridItem: View {
    let item: LibraryItem

    var body: some View {
        Color(.secondarySystemBackground)
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .overlay {
                ZStack(alignment: .topLeading) {
                    coverImage

                    HStack(spacing: 4) {
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
                                .padding(4)
                                .background(.gray, in: Circle())
                        }
                    }
                    .padding(4)
                }
            }
            .clipped()
            .cornerRadius(8)
    }

    private var coverImage: some View {
        Group {
            if let url = item.libraryManga.manga.thumbnailUrl,
               let imageUrl = URL(string: url) {
                LazyImage(request: sourceImageRequest(url: imageUrl, sourceId: item.libraryManga.manga.source)) { state in
                    if let image = state.image {
                        image.resizable().scaledToFit()
                    } else {
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "book.closed")
                    .foregroundStyle(.secondary)
            }
    }
}
