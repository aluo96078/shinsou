import WidgetKit
import SwiftUI

// MARK: - LibraryWidget

struct LibraryWidget: Widget {
    let kind = "LibraryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: LibraryTimelineProvider()
        ) { entry in
            LibraryWidgetView(entry: entry)
        }
        .configurationDisplayName("書庫")
        .description("快速存取書庫中的漫畫")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - LibraryWidgetView (Router)

struct LibraryWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LibraryEntry

    var body: some View {
        switch family {
        case .systemMedium:
            LibraryMediumView(entry: entry)
        case .systemLarge:
            LibraryLargeView(entry: entry)
        default:
            LibraryMediumView(entry: entry)
        }
    }
}

// MARK: - Medium (4 封面，2×2)

private struct LibraryMediumView: View {
    let entry: LibraryEntry

    private var displayedMangas: [WidgetManga] {
        Array(entry.mangas.prefix(4))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 頂部標題列
            LibraryWidgetHeader(categoryName: entry.categoryName)

            if displayedMangas.isEmpty {
                Spacer()
                WidgetEmptyView(message: "書庫是空的")
                Spacer()
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(displayedMangas) { manga in
                        Link(destination: manga.deepLinkURL) {
                            LibraryCoverItem(manga: manga)
                        }
                    }

                    // 補足空位
                    if displayedMangas.count < 4 {
                        ForEach(0..<(4 - displayedMangas.count), id: \.self) { _ in
                            WidgetCoverPlaceholder()
                        }
                    }
                }
            }
        }
        .padding(12)
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Large (8 封面，4×2)

private struct LibraryLargeView: View {
    let entry: LibraryEntry

    private var displayedMangas: [WidgetManga] {
        Array(entry.mangas.prefix(8))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LibraryWidgetHeader(categoryName: entry.categoryName)
                .padding(.top, 4)

            if displayedMangas.isEmpty {
                Spacer()
                WidgetEmptyView(message: "書庫是空的")
                Spacer()
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(displayedMangas) { manga in
                        Link(destination: manga.deepLinkURL) {
                            LibraryCoverItem(manga: manga)
                        }
                    }

                    // 補足空位
                    if displayedMangas.count < 8 {
                        ForEach(0..<(8 - displayedMangas.count), id: \.self) { _ in
                            WidgetCoverPlaceholder()
                        }
                    }
                }
            }
        }
        .padding(12)
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - 頂部標題列

private struct LibraryWidgetHeader: View {
    let categoryName: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "books.vertical.fill")
                .foregroundStyle(.accentColor)
                .font(.caption)

            Text(categoryName ?? "書庫")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Spacer()

            // 顯示最後更新時間
            Text("書庫")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - 單一書庫封面項目

private struct LibraryCoverItem: View {
    let manga: WidgetManga

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            WidgetCoverImageView(coverData: manga.coverData, coverUrl: manga.coverUrl)
                .aspectRatio(2/3, contentMode: .fill)
                .clipped()
                .cornerRadius(6)

            // 底部漸層確保標題可讀
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )
            .cornerRadius(6)

            Text(manga.title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .padding(4)
        }
        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Previews

struct LibraryWidget_Previews: PreviewProvider {
    static let sampleEntry = LibraryEntry(
        date: .now,
        mangas: [
            WidgetManga(id: 1, title: "鬼滅之刃", coverUrl: nil, chapterName: nil, coverData: nil),
            WidgetManga(id: 2, title: "進擊的巨人", coverUrl: nil, chapterName: nil, coverData: nil),
            WidgetManga(id: 3, title: "咒術迴戰", coverUrl: nil, chapterName: nil, coverData: nil),
            WidgetManga(id: 4, title: "海賊王", coverUrl: nil, chapterName: nil, coverData: nil),
            WidgetManga(id: 5, title: "火影忍者", coverUrl: nil, chapterName: nil, coverData: nil),
            WidgetManga(id: 6, title: "死神", coverUrl: nil, chapterName: nil, coverData: nil),
            WidgetManga(id: 7, title: "龍珠超", coverUrl: nil, chapterName: nil, coverData: nil),
            WidgetManga(id: 8, title: "名偵探柯南", coverUrl: nil, chapterName: nil, coverData: nil),
        ],
        categoryName: nil
    )

    static var previews: some View {
        Group {
            LibraryWidgetView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium (4 封面)")

            LibraryWidgetView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large (8 封面)")
        }
    }
}
