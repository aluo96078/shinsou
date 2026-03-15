import CloudKit

/// CloudKit 不可用時拋出的錯誤。
enum CloudKitError: LocalizedError {
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "CloudKit 不可用，請確認已登入 iCloud 帳號且 App 具備 iCloud 權限。"
        }
    }
}

/// 管理 CloudKit 自訂 Zone 與 Subscription。
final class CloudKitZoneManager {

    static let shared = CloudKitZoneManager()

    let zoneName = "ShinsouSyncZone"
    private(set) lazy var zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

    private let subscriptionID = "ShinsouSyncZone-subscription"
    private let zoneCreatedKey = "cloudkit.zoneCreated"
    private let subscriptionCreatedKey = "cloudkit.subscriptionCreated"

    /// CloudKit 是否可用（需要 iCloud 帳號 + provisioning profile 包含 CloudKit 權限）。
    var isAvailable: Bool {
        guard FileManager.default.ubiquityIdentityToken != nil else { return false }
        return Self.hasCloudKitEntitlement
    }

    /// 解析 embedded.mobileprovision 檢查是否包含 CloudKit 服務。
    private static let hasCloudKitEntitlement: Bool = {
        guard let profileURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let profileData = try? Data(contentsOf: profileURL),
              let profileString = String(data: profileData, encoding: .ascii) else {
            return false
        }
        // mobileprovision 是 CMS 簽名資料，plist 嵌在其中
        guard let plistStart = profileString.range(of: "<?xml"),
              let plistEnd = profileString.range(of: "</plist>") else {
            return false
        }
        let plistXML = String(profileString[plistStart.lowerBound...plistEnd.upperBound])
        guard let plistData = plistXML.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let services = entitlements["com.apple.developer.icloud-services"] as? [String] else {
            return false
        }
        return services.contains("CloudKit") || services.contains("CloudKit-Anonymous")
    }()

    /// 延遲建立 CKContainer，避免在缺少 entitlements 時閃退。
    private var _container: CKContainer?
    var container: CKContainer? {
        if let c = _container { return c }
        guard isAvailable else { return nil }
        let c = CKContainer(identifier: "iCloud.dev.shinsou.ios")
        _container = c
        return c
    }

    private init() {}

    /// 取得可用的 CKContainer，不可用時拋出錯誤。
    func requireContainer() throws -> CKContainer {
        guard let c = container else { throw CloudKitError.notAvailable }
        return c
    }

    /// 確保自訂 Zone 存在。
    func ensureZoneExists() async throws {
        let ckContainer = try requireContainer()
        guard !UserDefaults.standard.bool(forKey: zoneCreatedKey) else { return }

        let zone = CKRecordZone(zoneID: zoneID)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone])

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success:
                    UserDefaults.standard.set(true, forKey: self.zoneCreatedKey)
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            ckContainer.privateCloudDatabase.add(operation)
        }
    }

    /// 確保 Zone 層級的 Subscription 存在（用於接收推播通知）。
    func ensureSubscriptionExists() async throws {
        let ckContainer = try requireContainer()
        guard !UserDefaults.standard.bool(forKey: subscriptionCreatedKey) else { return }

        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: subscriptionID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true  // 靜默推播
        subscription.notificationInfo = notificationInfo

        let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription])

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifySubscriptionsResultBlock = { result in
                switch result {
                case .success:
                    UserDefaults.standard.set(true, forKey: self.subscriptionCreatedKey)
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            ckContainer.privateCloudDatabase.add(operation)
        }
    }

    /// 刪除自訂 Zone（清除所有雲端資料）。
    func deleteZone() async throws {
        let ckContainer = try requireContainer()
        let operation = CKModifyRecordZonesOperation(recordZoneIDsToDelete: [zoneID])

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            operation.modifyRecordZonesResultBlock = { result in
                switch result {
                case .success:
                    UserDefaults.standard.set(false, forKey: self.zoneCreatedKey)
                    UserDefaults.standard.set(false, forKey: self.subscriptionCreatedKey)
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            ckContainer.privateCloudDatabase.add(operation)
        }
    }
}
