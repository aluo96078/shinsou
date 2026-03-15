import Foundation

/// 同步操作的狀態。
enum SyncStatus: Equatable {
    case idle
    case syncing
    case success(Date)
    case error(String)

    var isActive: Bool {
        if case .syncing = self { return true }
        return false
    }
}

/// iCloud 帳號狀態。
enum ICloudAccountStatus: Equatable {
    case available
    case noAccount
    case restricted
    case couldNotDetermine
    case temporarilyUnavailable
    case unknown
}
