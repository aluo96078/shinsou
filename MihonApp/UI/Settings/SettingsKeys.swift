import Foundation

/// Centralised UserDefaults key definitions for all app settings.
enum SettingsKeys {

    // MARK: - General
    static let languagePreference        = "settings.general.languagePreference"
    static let dateFormat                = "settings.general.dateFormat"
    static let confirmBeforeClosing      = "settings.general.confirmBeforeClosing"
    static let defaultStartingScreen     = "settings.general.defaultStartingScreen"

    // MARK: - Appearance
    static let appTheme                  = "settings.appearance.appTheme"
    static let appTintColor              = "settings.appearance.appTintColor"
    static let timestampFormat           = "settings.appearance.timestampFormat"
    static let relativeTimestamps        = "settings.appearance.relativeTimestamps"

    // MARK: - Library
    static let defaultCategory           = "settings.library.defaultCategory"
    static let categoryUpdateBehaviour   = "settings.library.categoryUpdateBehaviour"
    static let globalUpdateRestrictions  = "settings.library.globalUpdateRestrictions"
    static let autoRefreshMetadata       = "settings.library.autoRefreshMetadata"
    static let downloadOnly              = "settings.library.downloadOnly"

    // MARK: - Reader
    static let defaultReadingMode        = "settings.reader.defaultReadingMode"
    static let defaultOrientationLock    = "settings.reader.defaultOrientationLock"
    static let doubleTapToZoom           = "settings.reader.doubleTapToZoom"
    static let showPageNumber            = "settings.reader.showPageNumber"
    static let keepScreenOn              = "settings.reader.keepScreenOn"
    static let skipFilteredChapters      = "settings.reader.skipFilteredChapters"
    static let skipReadChapters          = "settings.reader.skipReadChapters"
    static let skipDuplicateChapters     = "settings.reader.skipDuplicateChapters"
    static let defaultColorFilter        = "settings.reader.defaultColorFilter"
    static let defaultColorFilterBright  = "settings.reader.defaultColorFilterBrightness"
    static let splitTallImages           = "settings.reader.splitTallImages"
    static let webtoonSidePadding        = "settings.reader.webtoonSidePadding"

    // MARK: - Appearance (extended)
    static let amoledDark                = "settings.appearance.amoledDark"

    // MARK: - Downloads
    static let downloadLocation          = "settings.downloads.downloadLocation"
    static let autoDownloadNewChapters   = "settings.downloads.autoDownloadNewChapters"
    static let deleteAfterReading        = "settings.downloads.deleteAfterReading"
    static let downloadOnWifiOnly        = "settings.downloads.downloadOnWifiOnly"
    static let parallelDownloads         = "settings.downloads.parallelDownloads"
    static let removeAfterMarkedRead     = "settings.downloads.removeAfterMarkedRead"

    // MARK: - Tracking
    static let autoSyncAfterRead         = "settings.tracking.autoSyncAfterRead"
    static let updateProgressAfterRead   = "settings.tracking.updateProgressAfterRead"

    // MARK: - Browse
    static let checkExtensionUpdates     = "settings.browse.checkExtensionUpdates"
    static let showNSFWSources           = "settings.browse.showNSFWSources"
    static let extensionRepositories     = "settings.browse.extensionRepositories"
    static let enabledLanguages          = "settings.browse.enabledLanguages"
    static let pinnedSourceIds           = "settings.browse.pinnedSourceIds"

    // MARK: - Security
    static let appLockEnabled            = "settings.security.appLockEnabled"
    static let lockAfterDelay            = "settings.security.lockAfterDelay"
    static let secureScreen              = "settings.security.secureScreen"
    static let incognitoMode             = "settings.security.incognitoMode"

    // MARK: - Advanced
    static let dnsOverHTTPS              = "settings.advanced.dnsOverHTTPS"
}
