import Foundation

/// iCloud 同步相關的 UserDefaults 鍵值。
extension SettingsKeys {

    // MARK: - iCloud Drive 備份同步
    static let icloudDriveBackupEnabled  = "settings.sync.icloudDriveBackupEnabled"
    static let lastICloudBackupDate      = "settings.sync.lastICloudBackupDate"

    // MARK: - CloudKit 即時同步
    static let cloudKitSyncEnabled       = "settings.sync.cloudKitSyncEnabled"
    static let lastCloudKitSyncDate      = "settings.sync.lastCloudKitSyncDate"
    static let cloudKitServerChangeToken = "settings.sync.cloudKitServerChangeToken"
}
