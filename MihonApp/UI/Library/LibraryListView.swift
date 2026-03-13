import SwiftUI
import MihonDomain
import MihonUI
import Nuke
import NukeUI

struct LibraryListView: View {
    let items: [LibraryItem]
    @ObservedObject var viewModel: LibraryViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    Group {
                        if viewModel.isSelectionMode {
                            Button {
                                viewModel.toggleSelection(item.id)
                            } label: {
                                LibraryListRow(item: item)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(value: item.libraryManga.manga.id) {
                                LibraryListRow(item: item)
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
                    .background(
                        viewModel.selectedMangaIds.contains(item.id)
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                    )

                    Divider().padding(.leading, 72)
                }
            }
        }
    }
}

private struct LibraryListRow: View {
    let item: LibraryItem

    var body: some View {
        HStack(spacing: 12) {
            // Cover thumbnail
            coverThumbnail

            // Title and info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.libraryManga.manga.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                if let author = item.libraryManga.manga.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Badges
            HStack(spacing: 4) {
                if item.downloadCount > 0 {
                    BadgeView(count: Int(item.downloadCount), color: .green)
                }
                if item.unreadCount > 0 {
                    BadgeView(count: Int(item.unreadCount), color: Color.accentColor)
                }
                if item.isLocal {
                    Image(systemName: "internaldrive")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var coverThumbnail: some View {
        if let url = item.libraryManga.manga.thumbnailUrl,
           let imageUrl = URL(string: url) {
            LazyImage(request: sourceImageRequest(url: imageUrl, sourceId: item.libraryManga.manga.source)) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholderView
                }
            }
            .frame(width: 48, height: 64)
            .clipped()
            .cornerRadius(4)
        } else {
            placeholderView
                .frame(width: 48, height: 64)
                .cornerRadius(4)
        }
    }

    @MainActor
    private func sourceImageRequest(url: URL, sourceId: Int64) -> ImageRequest {
        if let jsProxy = SourceManager.shared.getCatalogueSource(id: sourceId) as? JSSourceProxy {
            let headers = jsProxy.sourceHeaders
            if !headers.isEmpty {
                var urlRequest = URLRequest(url: url)
                for (key, value) in headers {
                    urlRequest.setValue(value, forHTTPHeaderField: key)
                }
                return ImageRequest(urlRequest: urlRequest)
            }
        }
        return ImageRequest(url: url)
    }

    private var placeholderView: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "book.closed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
    }
}
