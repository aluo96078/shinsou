import Foundation

public enum AppConstants {
    public static let appName = "Shinsou"
    public static let appVersion = "0.1.0"
    public static let databaseFileName = "mihon.db"

    public static let defaultCoverCacheSize = 100 // MB
    public static let defaultPageCacheSize = 500 // MB
    public static let networkCacheSize = 5 * 1024 * 1024 // 5MB

    public static let maxConcurrentSourceDownloads = 5
    public static let maxConcurrentPageDownloads = 5
    public static let readerPreloadPages = 4

    public static let httpMaxConnectionsPerHost = 3
    public static let trackUpdateDebounceSeconds: TimeInterval = 3.0
}
