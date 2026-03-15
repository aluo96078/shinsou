import WidgetKit
import SwiftUI

// MARK: - RecentUpdatesWidget

struct RecentUpdatesWidget: Widget {
    let kind = "RecentUpdatesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: UpdatesTimelineProvider()
        ) { entry in
            RecentUpdatesWidgetView(entry: entry)
        }
        .configurationDisplayName("最新更新")
        .description("顯示最近更新的漫畫")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - RecentUpdatesWidgetView (Router)

struct RecentUpdatesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UpdateEntry

    var body: some View {
        switch family {
        case .systemSmall:
            RecentUpdatesSmallView(entry: entry)
        case .systemMedium:
            RecentUpdatesMediumView(entry: entry)
        case .systemLarge:
            RecentUpdatesLargeView(entry: entry)
        default:
            RecentUpdatesSmallView(entry: entry)
        }
    }
}

// MARK: - Small (1 封面)

private struct RecentUpdatesSmallView: View {
    let entry: UpdateEntry

    private var manga: WidgetManga? { entry.updates.first }

    var body: some View {
        Group {
            if let manga {
                Link(destination: manga.deepLinkURL) {
                    ZStack(alignment: .bottomLeading) {
                        WidgetCoverImageView(coverData: manga.coverData, coverUrl: manga.coverUrl)
                            .aspectRatio(2/3, contentMode: .fill)

                        // 漸層遮罩確保文字可讀性
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.75)],
                            startPoint: .center,
                            endPoint: .bottom
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(manga.title)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            if let chapter = manga.chapterName {
                                Text(chapter)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                        .padding(8)
                    }
                }
            } else {
                WidgetEmptyView(message: "尚無更新")
            }
        }
        .widgetURL(manga?.deepLinkURL)
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Medium (3 封面橫排)

private struct RecentUpdatesMediumView: View {
    let entry: UpdateEntry

    private var displayedMangas: [WidgetManga] {
        Array(entry.updates.prefix(3))
    }

    var body: some View {
        HStack(spacing: 8) {
            if displayedMangas.isEmpty {
                WidgetEmptyView(message: "尚無更新")
            } else {
                ForEach(displayedMangas) { manga in
                    Link(destination: manga.deepLinkURL) {
                        RecentUpdatesCoverItem(manga: manga)
                    }
                }

                // 用空白填滿剩餘位置，保持版面整齊
                if displayedMangas.count < 3 {
                    ForEach(0..<(3 - displayedMangas.count), id: \.self) { _ in
                        WidgetCoverPlaceholder()
                    }
                }
            }
        }
        .padding(12)
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - Large (6 封面 Grid)

private struct RecentUpdatesLargeView: View {
    let entry: UpdateEntry

    private var displayedMangas: [WidgetManga] {
        Array(entry.updates.prefix(6))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bell.badge")
                    .foregroundStyle(.accentColor)
                Text("最新更新")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if displayedMangas.isEmpty {
                Spacer()
                WidgetEmptyView(message: "尚無更新")
                Spacer()
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(displayedMangas) { manga in
                        Link(destination: manga.deepLinkURL) {
                            RecentUpdatesCoverItem(manga: manga)
                        }
                    }

                    // 填充空位
                    if displayedMangas.count < 6 {
                        ForEach(0..<(6 - displayedMangas.count), id: \.self) { _ in
                            WidgetCoverPlaceholder()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .containerBackground(.background, for: .widget)
    }
}

// MARK: - 單一封面項目（含標題與章節）

private struct RecentUpdatesCoverItem: View {
    let manga: WidgetManga

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            WidgetCoverImageView(coverData: manga.coverData, coverUrl: manga.coverUrl)
                .aspectRatio(2/3, contentMode: .fill)
                .clipped()
                .cornerRadius(6)

            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .center,
                endPoint: .bottom
            )
            .cornerRadius(6)

            VStack(alignment: .leading, spacing: 1) {
                Text(manga.title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let chapter = manga.chapterName {
                    Text(chapter)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .padding(5)
        }
    }
}

// MARK: - Previews

struct RecentUpdatesWidget_Previews: PreviewProvider {
    static let sampleEntry = UpdateEntry(
        date: .now,
        updates: [
            WidgetManga(id: 1, title: "鬼滅之刃", coverUrl: nil, chapterName: "第 205 話", coverData: nil),
            WidgetManga(id: 2, title: "進擊的巨人", coverUrl: nil, chapterName: "第 139 話", coverData: nil),
            WidgetManga(id: 3, title: "咒術迴戰", coverUrl: nil, chapterName: "第 238 話", coverData: nil),
            WidgetManga(id: 4, title: "海賊王", coverUrl: nil, chapterName: "第 1089 話", coverData: nil),
            WidgetManga(id: 5, title: "名偵探柯南", coverUrl: nil, chapterName: "第 1100 話", coverData: nil),
            WidgetManga(id: 6, title: "Dragon Ball", coverUrl: nil, chapterName: "第 519 話", coverData: nil),
        ]
    )

    static var previews: some View {
        Group {
            RecentUpdatesWidgetView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")

            RecentUpdatesWidgetView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")

            RecentUpdatesWidgetView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("Large")
        }
    }
}
