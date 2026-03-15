import Foundation
import CloudKit
import Combine

/// 同步總管：統合 iCloud Drive 備份同步 與 CloudKit 即時同步。
@MainActor
final class SyncManager: ObservableObject {

    static let shared = SyncManager()

    // MARK: - Published State

    @Published var iCloudAccountStatus: ICloudAccountStatus = .unknown
    @Published var iCloudDriveStatus: SyncStatus = .idle
    @Published var cloudKitStatus: SyncStatus = .idle
    @Published var cloudBackups: [URL] = []

    // MARK: - Settings

    var isICloudDriveBackupEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: SettingsKeys.icloudDriveBackupEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: SettingsKeys.icloudDriveBackupEnabled) }
    }

    var isCloudKitSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: SettingsKeys.cloudKitSyncEnabled) }
        set { UserDefaults.standard.set(newValue, forKey: SettingsKeys.cloudKitSyncEnabled) }
    }

    var lastICloudBackupDate: Date? {
        let ts = UserDefaults.standard.double(forKey: SettingsKeys.lastICloudBackupDate)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    var lastCloudKitSyncDate: Date? {
        let ts = UserDefaults.standard.double(forKey: SettingsKeys.lastCloudKitSyncDate)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    // MARK: - Dependencies

    private let iCloudDrive = ICloudDriveBackupSync.shared
    private let monitor = ICloudDriveMonitor.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // 監控 iCloud Drive 備份變更
        monitor.backupsDidChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshCloudBackups()
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    /// App 啟動時呼叫，檢查 iCloud 狀態並啟動必要服務。
    func setup() {
        Task {
            await checkICloudAccount()
            refreshCloudBackups()

            if isICloudDriveBackupEnabled {
                monitor.startMonitoring()
            }

            // 啟用 CloudKit DB 變更監聽
            if isCloudKitSyncEnabled {
                DIContainer.shared.enableSyncObserver()
                // 啟動時同步
                await performCloudKitSync()
            }
        }
    }

    // MARK: - iCloud Account

    func checkICloudAccount() async {
        // 使用 FileManager 檢查 iCloud 可用性，避免在缺少 entitlements 時 crash
        if FileManager.default.ubiquityIdentityToken != nil {
            iCloudAccountStatus = .available
        } else {
            iCloudAccountStatus = .noAccount
        }
    }

    // MARK: - iCloud Drive Backup

    /// 手動上傳當前最新備份到 iCloud Drive。
    func uploadLatestBackupToICloud() async {
        guard iCloudDrive.isAvailable else {
            iCloudDriveStatus = .error("iCloud Drive 不可用")
            return
        }

        iCloudDriveStatus = .syncing

        do {
            // 先建立一份新備份
            let localURL = try await AutoBackupManager.shared.performBackup()
            // 上傳到 iCloud Drive
            try iCloudDrive.uploadBackup(localURL: localURL)
            iCloudDriveStatus = .success(Date())
            refreshCloudBackups()
        } catch {
            iCloudDriveStatus = .error(error.localizedDescription)
        }
    }

    /// 備份完成後自動上傳（由 AutoBackupManager 呼叫）。
    func autoUploadIfEnabled(localURL: URL) {
        guard isICloudDriveBackupEnabled, iCloudDrive.isAvailable else { return }
        Task {
            do {
                try iCloudDrive.uploadBackup(localURL: localURL)
                iCloudDriveStatus = .success(Date())
                refreshCloudBackups()
            } catch {
                iCloudDriveStatus = .error(error.localizedDescription)
            }
        }
    }

    /// 從 iCloud Drive 下載並還原備份。
    func restoreFromCloud(cloudURL: URL) async throws -> URL {
        iCloudDriveStatus = .syncing
        do {
            let localURL = try iCloudDrive.downloadBackup(cloudURL: cloudURL)
            iCloudDriveStatus = .idle
            return localURL
        } catch {
            iCloudDriveStatus = .error(error.localizedDescription)
            throw error
        }
    }

    /// 重新整理雲端備份列表。
    func refreshCloudBackups() {
        cloudBackups = iCloudDrive.listCloudBackups()
    }

    /// 檢查是否為新裝置（本機書庫為空且雲端有備份）。
    func checkNewDeviceRestore() async -> Bool {
        guard iCloudDrive.isAvailable else { return false }
        let backups = iCloudDrive.listCloudBackups()
        guard !backups.isEmpty else { return false }

        // 檢查本機是否有收藏漫畫
        let mangaRepo = DIContainer.shared.mangaRepository
        let hasFavorites = (try? await mangaRepo.getFavorites())?.isEmpty == false
        return !hasFavorites
    }

    // MARK: - CloudKit

    /// 手動觸發 CloudKit 同步。
    func performCloudKitSync() async {
        guard isCloudKitSyncEnabled else { return }
        guard CloudKitZoneManager.shared.isAvailable else {
            cloudKitStatus = .error("iCloud 不可用，請先登入 iCloud 帳號")
            return
        }
        cloudKitStatus = .syncing

        do {
            try await CloudKitSyncEngine.shared.sync()
            let now = Date()
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: SettingsKeys.lastCloudKitSyncDate)
            cloudKitStatus = .success(now)
        } catch {
            cloudKitStatus = .error(error.localizedDescription)
        }
    }

    /// 重設 CloudKit 雲端資料。
    func resetCloudKitData() async throws {
        try await CloudKitSyncEngine.shared.resetCloudData()
        UserDefaults.standard.removeObject(forKey: SettingsKeys.cloudKitServerChangeToken)
        UserDefaults.standard.removeObject(forKey: SettingsKeys.lastCloudKitSyncDate)
        cloudKitStatus = .idle
    }
}
