import Foundation
import GRDB

/// GRDB TransactionObserver：自動攔截 manga/chapter/track/history/category 表的寫入操作，
/// 將變更記錄到 CloudKitChangeTracker，並觸發 debounced 推送。
final class SyncTransactionObserver: TransactionObserver {

    /// 要監聽的表名
    private let observedTables: Set<String> = ["manga", "chapter", "track", "history", "category"]

    /// 本次 transaction 中偵測到的變更
    private var pendingEvents: [(table: String, rowID: Int64)] = []

    func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        observedTables.contains(eventKind.tableName)
    }

    func databaseDidChange(with event: DatabaseEvent) {
        pendingEvents.append((table: event.tableName, rowID: event.rowID))
    }

    func databaseDidCommit(_ db: Database) {
        let events = pendingEvents
        pendingEvents = []

        guard !events.isEmpty else { return }
        guard UserDefaults.standard.bool(forKey: SettingsKeys.cloudKitSyncEnabled) else { return }

        // 在背景處理
        Task { @MainActor in
            for event in events {
                let changeType: CloudKitChangeTracker.ChangeType
                switch event.table {
                case "manga":    changeType = .manga
                case "chapter":  changeType = .chapter
                case "track":    changeType = .track
                case "history":  changeType = .history
                case "category": changeType = .category
                default: continue
                }

                CloudKitChangeTracker.shared.trackChange(
                    type: changeType,
                    recordKey: "\(event.table)-\(event.rowID)",
                    localId: event.rowID
                )
            }

            // 觸發 debounced 推送
            CloudKitSyncEngine.shared.schedulePush()
        }
    }

    func databaseDidRollback(_ db: Database) {
        pendingEvents = []
    }
}
