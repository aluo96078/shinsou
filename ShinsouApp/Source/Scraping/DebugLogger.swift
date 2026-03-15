import Foundation

/// 應用內日誌收集器，用於在 UI 上顯示解析除錯資訊。
@MainActor
final class DebugLogger: ObservableObject {
    static let shared = DebugLogger()

    @Published private(set) var logs: [String] = []

    private init() {}

    func log(_ message: String) {
        print(message)
        logs.append(message)
        // 最多保留 200 條
        if logs.count > 200 {
            logs.removeFirst(logs.count - 200)
        }
    }

    func clear() {
        logs.removeAll()
    }

    /// 取得最近的日誌文字
    var recentText: String {
        logs.suffix(50).joined(separator: "\n")
    }
}

/// 從非 MainActor 上下文安全地記錄日誌
func debugLog(_ message: String) {
    print(message)
    Task { @MainActor in
        DebugLogger.shared.log(message)
    }
}
