import Foundation

/// 離線變更佇列：追蹤需要推送到 CloudKit 的本機變更。
/// 使用獨立的 JSON 檔案儲存，不修改主資料庫 schema。
final class CloudKitChangeTracker {

    static let shared = CloudKitChangeTracker()

    /// 變更類型
    enum ChangeType: String, Codable {
        case manga
        case chapter
        case category
        case track
        case history
    }

    /// 單筆變更記錄
    struct PendingChange: Codable, Equatable {
        let type: ChangeType
        /// 用於識別記錄的 key（與 CKRecord.ID recordName 對應）
        let recordKey: String
        /// 對應的本機資料庫 ID
        let localId: Int64
        /// 變更時間戳
        let timestamp: TimeInterval

        static func == (lhs: PendingChange, rhs: PendingChange) -> Bool {
            lhs.type == rhs.type && lhs.recordKey == rhs.recordKey
        }
    }

    private var pendingChanges: [PendingChange] = []
    private let queue = DispatchQueue(label: "dev.shinsou.ios.changeTracker", qos: .utility)
    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let syncDir = appSupport.appendingPathComponent("Sync", isDirectory: true)
        try? FileManager.default.createDirectory(at: syncDir, withIntermediateDirectories: true)
        fileURL = syncDir.appendingPathComponent("pending_changes.json")
        loadFromDisk()
    }

    // MARK: - Public API

    /// 記錄一筆待推送的變更。
    func trackChange(type: ChangeType, recordKey: String, localId: Int64) {
        queue.sync {
            let change = PendingChange(
                type: type,
                recordKey: recordKey,
                localId: localId,
                timestamp: Date().timeIntervalSince1970
            )
            // 移除同一 record 的舊變更（去重）
            pendingChanges.removeAll { $0.type == type && $0.recordKey == recordKey }
            pendingChanges.append(change)
            saveToDisk()
        }
    }

    /// 取得所有待推送的變更。
    func getPendingChanges() -> [PendingChange] {
        queue.sync { pendingChanges }
    }

    /// 移除已成功推送的變更。
    func removeChanges(_ changes: [PendingChange]) {
        queue.sync {
            let keysToRemove = Set(changes.map { "\($0.type.rawValue)-\($0.recordKey)" })
            pendingChanges.removeAll { keysToRemove.contains("\($0.type.rawValue)-\($0.recordKey)") }
            saveToDisk()
        }
    }

    /// 清除所有待推送變更。
    func clearAll() {
        queue.sync {
            pendingChanges.removeAll()
            saveToDisk()
        }
    }

    /// 是否有待推送的變更。
    var hasPendingChanges: Bool {
        queue.sync { !pendingChanges.isEmpty }
    }

    // MARK: - Persistence

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(pendingChanges) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: fileURL),
              let changes = try? JSONDecoder().decode([PendingChange].self, from: data) else { return }
        pendingChanges = changes
    }
}
