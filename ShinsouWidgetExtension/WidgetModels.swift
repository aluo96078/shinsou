import Foundation

// MARK: - AppGroup Identifier
// 主 App 與 Widget Extension 共用的 AppGroup Container
enum WidgetConstants {
    static let appGroupIdentifier = "group.dev.shinsou.ios"
    static let deepLinkScheme = "shinsou"

    // UserDefaults keys
    static let recentUpdatesKey = "widget_recent_updates"
    static let libraryMangaKey = "widget_library_manga"

    // 封面快取目錄名稱（存放在 AppGroup shared container）
    static let coverCacheDirectory = "widget_covers"
}

// MARK: - WidgetManga
/// Widget 專用的輕量 Manga 資料模型
/// 由主 App 序列化後存入共用的 UserDefaults，供 Widget 讀取
public struct WidgetManga: Identifiable, Codable, Hashable {
    public let id: Int64
    public let title: String
    public let coverUrl: String?
    public let chapterName: String?
    /// 預先下載的封面圖片資料（widget 無法即時發起 HTTP 請求）
    public let coverData: Data?

    public init(
        id: Int64,
        title: String,
        coverUrl: String? = nil,
        chapterName: String? = nil,
        coverData: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.coverUrl = coverUrl
        self.chapterName = chapterName
        self.coverData = coverData
    }

    /// 產生跳轉到漫畫詳情頁的 Deep Link URL
    var deepLinkURL: URL {
        URL(string: "\(WidgetConstants.deepLinkScheme)://manga/\(id)")!
    }
}

// MARK: - WidgetDataStore
/// 負責在主 App 與 Widget 之間讀寫共用資料
public final class WidgetDataStore {
    public static let shared = WidgetDataStore()

    private let defaults: UserDefaults?

    private init() {
        defaults = UserDefaults(suiteName: WidgetConstants.appGroupIdentifier)
    }

    // MARK: - 寫入（由主 App 呼叫）

    public func saveRecentUpdates(_ mangas: [WidgetManga]) {
        guard let data = try? JSONEncoder().encode(mangas) else { return }
        defaults?.set(data, forKey: WidgetConstants.recentUpdatesKey)
    }

    public func saveLibraryManga(_ mangas: [WidgetManga]) {
        guard let data = try? JSONEncoder().encode(mangas) else { return }
        defaults?.set(data, forKey: WidgetConstants.libraryMangaKey)
    }

    // MARK: - 讀取（由 Widget Extension 呼叫）

    public func loadRecentUpdates() -> [WidgetManga] {
        guard
            let data = defaults?.data(forKey: WidgetConstants.recentUpdatesKey),
            let mangas = try? JSONDecoder().decode([WidgetManga].self, from: data)
        else { return [] }
        return mangas
    }

    public func loadLibraryManga() -> [WidgetManga] {
        guard
            let data = defaults?.data(forKey: WidgetConstants.libraryMangaKey),
            let mangas = try? JSONDecoder().decode([WidgetManga].self, from: data)
        else { return [] }
        return mangas
    }
}
