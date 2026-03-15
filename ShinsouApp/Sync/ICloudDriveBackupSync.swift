import Foundation

/// 管理 iCloud Drive 中的 `.shinsoubackup` 備份檔案。
/// 使用 `FileManager` 的 ubiquity container 進行上傳、下載、列舉與清理。
final class ICloudDriveBackupSync {

    static let shared = ICloudDriveBackupSync()

    /// iCloud container identifier
    private let containerIdentifier = "iCloud.dev.shinsou.ios"

    /// 雲端備份資料夾名稱
    private let cloudBackupFolder = "Backups"

    /// 保留最多幾份雲端備份
    private let maxCloudBackups = 3

    private init() {}

    // MARK: - Container

    /// 取得 iCloud ubiquity container 的 Documents 目錄。
    /// 回傳 nil 表示使用者未登入 iCloud 或 container 不可用。
    var cloudDocumentsURL: URL? {
        FileManager.default
            .url(forUbiquityContainerIdentifier: containerIdentifier)?
            .appendingPathComponent("Documents", isDirectory: true)
    }

    /// 雲端備份資料夾路徑。
    var cloudBackupDirectoryURL: URL? {
        cloudDocumentsURL?.appendingPathComponent(cloudBackupFolder, isDirectory: true)
    }

    /// iCloud Drive 是否可用。
    var isAvailable: Bool {
        cloudDocumentsURL != nil
    }

    // MARK: - Upload

    /// 將本機備份檔案上傳（複製）到 iCloud Drive。
    /// - Parameter localURL: 本機 `.shinsoubackup` 檔案路徑
    /// - Returns: 雲端檔案 URL
    @discardableResult
    func uploadBackup(localURL: URL) throws -> URL {
        guard let backupDir = cloudBackupDirectoryURL else {
            throw SyncError.iCloudNotAvailable
        }

        let fm = FileManager.default

        // 確保雲端資料夾存在
        if !fm.fileExists(atPath: backupDir.path) {
            try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }

        let destURL = backupDir.appendingPathComponent(localURL.lastPathComponent)

        // 如果目標已存在，先移除
        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }

        try fm.copyItem(at: localURL, to: destURL)

        // 記錄上傳時間
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: SettingsKeys.lastICloudBackupDate)

        // 清理多餘的雲端備份
        cleanupCloudBackups()

        return destURL
    }

    // MARK: - List

    /// 列舉 iCloud Drive 中的備份檔案，依修改日期由新到舊排序。
    func listCloudBackups() -> [URL] {
        guard let backupDir = cloudBackupDirectoryURL else { return [] }
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return contents
            .filter { $0.pathExtension == "shinsoubackup" }
            .sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return dateA > dateB
            }
    }

    // MARK: - Download

    /// 下載雲端備份到本機暫存目錄。
    /// - Parameter cloudURL: iCloud Drive 中的備份檔案 URL
    /// - Returns: 本機暫存檔案 URL
    func downloadBackup(cloudURL: URL) throws -> URL {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("ShinsouRestore", isDirectory: true)

        if !fm.fileExists(atPath: tempDir.path) {
            try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }

        let destURL = tempDir.appendingPathComponent(cloudURL.lastPathComponent)

        if fm.fileExists(atPath: destURL.path) {
            try fm.removeItem(at: destURL)
        }

        // 啟動 iCloud 下載（如果檔案尚未在本機）
        try fm.startDownloadingUbiquitousItem(at: cloudURL)

        // 複製到暫存目錄
        try fm.copyItem(at: cloudURL, to: destURL)

        return destURL
    }

    // MARK: - Cleanup

    /// 保留最新的 `maxCloudBackups` 份雲端備份，刪除較舊的。
    func cleanupCloudBackups() {
        let backups = listCloudBackups()
        guard backups.count > maxCloudBackups else { return }

        let toDelete = backups.dropFirst(maxCloudBackups)
        for url in toDelete {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Delete

    /// 刪除所有雲端備份。
    func deleteAllCloudBackups() {
        for url in listCloudBackups() {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Errors

enum SyncError: LocalizedError {
    case iCloudNotAvailable
    case backupNotFound
    case downloadFailed(String)
    case uploadFailed(String)
    case cloudKitError(String)

    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud 不可用，請確認已登入 iCloud 帳號"
        case .backupNotFound:
            return "找不到備份檔案"
        case .downloadFailed(let msg):
            return "下載失敗：\(msg)"
        case .uploadFailed(let msg):
            return "上傳失敗：\(msg)"
        case .cloudKitError(let msg):
            return "CloudKit 錯誤：\(msg)"
        }
    }
}
