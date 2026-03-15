import Foundation
import BackgroundTasks

// MARK: - AutoBackupManager

/// 管理自動備份排程與本機備份檔案的生命週期。
/// 使用 BGProcessingTask 在背景執行備份，並保留最近 N 份備份。
final class AutoBackupManager: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = AutoBackupManager()

    // MARK: - Constants

    static let taskIdentifier = "com.shinsou.autobackup"
    /// 保留的最大備份數量（超過時刪除最舊的）
    private let maxBackups = 5

    private init() {}

    // MARK: - Directories

    /// 備份存放目錄：`<Documents>/Backups/`
    var backupDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Backups", isDirectory: true)
    }

    /// 已存在的備份清單（依修改日期由新到舊排序）
    var existingBackups: [URL] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return contents
            .filter { $0.pathExtension == "shinsoubackup" }
            .sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return dateA > dateB  // 最新排最前
            }
    }

    // MARK: - Background Task Registration

    /// 在 `application(_:didFinishLaunchingWithOptions:)` 中呼叫，向系統註冊背景任務。
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self?.handleBackgroundTask(processingTask)
        }
    }

    // MARK: - Schedule

    /// 排程下一次自動備份（建議在每次備份完成後呼叫）。
    /// 預設間隔：24 小時後，且要求外部電源。
    func scheduleBackup() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        // 最早執行時間：目前時間 + 24 小時
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch BGTaskScheduler.Error.notPermitted {
            // 未啟用背景模式時靜默失敗
        } catch BGTaskScheduler.Error.tooManyPendingTaskRequests {
            // 已有排程中的請求，忽略
        } catch {
            // 其他錯誤（例如 Info.plist 未設定 BGTaskSchedulerPermittedIdentifiers）
            print("[AutoBackupManager] scheduleBackup 失敗：\(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup

    /// 保留最新的 `maxBackups` 份備份，刪除較舊的檔案。
    func cleanupOldBackups() {
        let backups = existingBackups  // 已依日期排序（新 -> 舊）
        guard backups.count > maxBackups else { return }

        let toDelete = backups.dropFirst(maxBackups)
        for url in toDelete {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("[AutoBackupManager] 刪除舊備份失敗：\(url.lastPathComponent) - \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Backup Execution

    /// 手動觸發備份（可從 UI 或背景任務呼叫）。
    /// - Returns: 新建立的備份檔案 URL
    @discardableResult @MainActor
    func performBackup() async throws -> URL {
        let creator = BackupCreator()
        let url = try await creator.createBackup()
        cleanupOldBackups()
        // 排程下一次自動備份
        scheduleBackup()
        // 自動上傳到 iCloud Drive（如果設定啟用）
        SyncManager.shared.autoUploadIfEnabled(localURL: url)
        return url
    }

    // MARK: - Private

    private func handleBackgroundTask(_ task: BGProcessingTask) {
        // 到期時取消
        let backupTask = Task {
            do {
                try await performBackup()
                task.setTaskCompleted(success: true)
            } catch {
                print("[AutoBackupManager] 背景備份失敗：\(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            backupTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}

// MARK: - Convenience Extensions

extension AutoBackupManager {

    /// 取得備份目錄的磁碟使用量（Bytes），無法計算時回傳 nil
    var backupDirectorySize: Int64? {
        let fm = FileManager.default
        let backups = existingBackups
        guard !backups.isEmpty else { return 0 }
        var total: Int64 = 0
        for url in backups {
            if let attrs = try? fm.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    /// 將備份目錄大小格式化為人類可讀字串（例如「1.2 MB」）
    var formattedBackupSize: String {
        guard let bytes = backupDirectorySize else { return "未知" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
