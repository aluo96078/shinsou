import UIKit
import CloudKit

/// AppDelegate：處理 CloudKit 靜默推播通知。
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 只在 CloudKit 同步啟用時註冊遠端推播
        if UserDefaults.standard.bool(forKey: SettingsKeys.cloudKitSyncEnabled) {
            application.registerForRemoteNotifications()
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // 確認 CloudKit 同步已啟用
        guard UserDefaults.standard.bool(forKey: SettingsKeys.cloudKitSyncEnabled) else {
            completionHandler(.noData)
            return
        }

        // 檢查是否為 CloudKit 通知
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        guard notification?.notificationType == .recordZone else {
            completionHandler(.noData)
            return
        }

        // 拉取雲端變更（確認 CloudKit 可用）
        guard CloudKitZoneManager.shared.isAvailable else {
            completionHandler(.noData)
            return
        }

        Task { @MainActor in
            do {
                try await CloudKitSyncEngine.shared.fetchChanges()
                let now = Date()
                UserDefaults.standard.set(now.timeIntervalSince1970, forKey: SettingsKeys.lastCloudKitSyncDate)
                SyncManager.shared.cloudKitStatus = .success(now)
                completionHandler(.newData)
            } catch {
                SyncManager.shared.cloudKitStatus = .error(error.localizedDescription)
                completionHandler(.failed)
            }
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {}

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[AppDelegate] 遠端推播註冊失敗：\(error.localizedDescription)")
    }
}
