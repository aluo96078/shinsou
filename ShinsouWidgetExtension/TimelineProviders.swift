import WidgetKit
import Foundation

// MARK: - UpdateEntry

struct UpdateEntry: TimelineEntry {
    let date: Date
    let updates: [WidgetManga]

    /// 佔位用的空白 Entry（Widget 尚未載入資料時使用）
    static var placeholder: UpdateEntry {
        UpdateEntry(
            date: .now,
            updates: (0..<6).map {
                WidgetManga(
                    id: Int64($0),
                    title: "漫畫標題",
                    coverUrl: nil,
                    chapterName: "第 \($0 + 1) 話",
                    coverData: nil
                )
            }
        )
    }
}

// MARK: - LibraryEntry

struct LibraryEntry: TimelineEntry {
    let date: Date
    let mangas: [WidgetManga]
    let categoryName: String?

    /// 佔位用的空白 Entry
    static var placeholder: LibraryEntry {
        LibraryEntry(
            date: .now,
            mangas: (0..<8).map {
                WidgetManga(
                    id: Int64($0),
                    title: "漫畫標題",
                    coverUrl: nil,
                    chapterName: nil,
                    coverData: nil
                )
            },
            categoryName: nil
        )
    }
}

// MARK: - UpdatesTimelineProvider

struct UpdatesTimelineProvider: TimelineProvider {
    typealias Entry = UpdateEntry

    // MARK: Placeholder
    /// 在 Widget Gallery 或資料尚未取得前顯示的佔位畫面
    func placeholder(in context: Context) -> UpdateEntry {
        .placeholder
    }

    // MARK: Snapshot
    /// 用於 Widget 預覽或快速顯示，使用已快取的資料，不等待非同步操作
    func getSnapshot(in context: Context, completion: @escaping (UpdateEntry) -> Void) {
        let updates = WidgetDataStore.shared.loadRecentUpdates()
        let entry = UpdateEntry(
            date: .now,
            updates: updates.isEmpty ? UpdateEntry.placeholder.updates : updates
        )
        completion(entry)
    }

    // MARK: Timeline
    /// 建立實際的 Timeline，每 30 分鐘刷新一次
    func getTimeline(in context: Context, completion: @escaping (Timeline<UpdateEntry>) -> Void) {
        let updates = WidgetDataStore.shared.loadRecentUpdates()
        let currentDate = Date.now
        let entry = UpdateEntry(date: currentDate, updates: updates)

        // 30 分鐘後重新整理
        let nextRefreshDate = Calendar.current.date(
            byAdding: .minute,
            value: 30,
            to: currentDate
        ) ?? currentDate.addingTimeInterval(1800)

        let timeline = Timeline(
            entries: [entry],
            policy: .after(nextRefreshDate)
        )
        completion(timeline)
    }
}

// MARK: - LibraryTimelineProvider

struct LibraryTimelineProvider: TimelineProvider {
    typealias Entry = LibraryEntry

    // MARK: Placeholder
    func placeholder(in context: Context) -> LibraryEntry {
        .placeholder
    }

    // MARK: Snapshot
    func getSnapshot(in context: Context, completion: @escaping (LibraryEntry) -> Void) {
        let mangas = WidgetDataStore.shared.loadLibraryManga()
        let entry = LibraryEntry(
            date: .now,
            mangas: mangas.isEmpty ? LibraryEntry.placeholder.mangas : mangas,
            categoryName: nil
        )
        completion(entry)
    }

    // MARK: Timeline
    /// 建立實際的 Timeline，每小時刷新一次（書庫資料變動頻率低於更新列表）
    func getTimeline(in context: Context, completion: @escaping (Timeline<LibraryEntry>) -> Void) {
        let mangas = WidgetDataStore.shared.loadLibraryManga()
        let currentDate = Date.now
        let entry = LibraryEntry(
            date: currentDate,
            mangas: mangas,
            categoryName: nil
        )

        // 1 小時後重新整理
        let nextRefreshDate = Calendar.current.date(
            byAdding: .hour,
            value: 1,
            to: currentDate
        ) ?? currentDate.addingTimeInterval(3600)

        let timeline = Timeline(
            entries: [entry],
            policy: .after(nextRefreshDate)
        )
        completion(timeline)
    }
}
