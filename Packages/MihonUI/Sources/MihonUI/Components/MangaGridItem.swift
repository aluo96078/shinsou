import SwiftUI
import MihonDomain
import NukeUI

public struct MangaGridItem: View {
    let title: String
    let coverUrl: String?
    let unreadCount: Int
    let downloadCount: Int
    let isLocal: Bool

    public init(
        title: String, coverUrl: String? = nil,
        unreadCount: Int = 0, downloadCount: Int = 0,
        isLocal: Bool = false
    ) {
        self.title = title
        self.coverUrl = coverUrl
        self.unreadCount = unreadCount
        self.downloadCount = downloadCount
        self.isLocal = isLocal
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                Color(.secondarySystemBackground)
                    .aspectRatio(2/3, contentMode: .fit)
                    .overlay {
                        coverImage
                            .scaledToFit()
                    }
                    .clipped()
                    .cornerRadius(8)

                badgeOverlay
            }

            Text(title)
                .font(.caption)
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        if let url = coverUrl, let imageUrl = URL(string: url) {
            LazyImage(url: imageUrl) { state in
                if let image = state.image {
                    image.resizable()
                } else {
                    placeholderView
                }
            }
        } else {
            placeholderView
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

    @ViewBuilder
    private var badgeOverlay: some View {
        HStack(spacing: 4) {
            if unreadCount > 0 {
                BadgeView(count: unreadCount, color: .accentColor)
            }
            if downloadCount > 0 {
                BadgeView(count: downloadCount, color: .green)
            }
            if isLocal {
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
