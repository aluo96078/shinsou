import Foundation
import Combine

/// 使用 NSMetadataQuery 監控 iCloud Drive 中的備份檔案變更。
/// 當偵測到新的備份檔案時發送通知（例如其他裝置上傳的備份）。
final class ICloudDriveMonitor {

    static let shared = ICloudDriveMonitor()

    /// 當雲端備份列表變更時發佈。
    let backupsDidChange = PassthroughSubject<[NSMetadataItem], Never>()

    private var query: NSMetadataQuery?
    private var isMonitoring = false

    private init() {}

    // MARK: - Start / Stop

    func startMonitoring() {
        guard !isMonitoring else { return }
        guard ICloudDriveBackupSync.shared.isAvailable else { return }

        let metadataQuery = NSMetadataQuery()
        metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        metadataQuery.predicate = NSPredicate(format: "%K LIKE '*.shinsoubackup'", NSMetadataItemFSNameKey)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidUpdate(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: metadataQuery
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(queryDidFinishGathering(_:)),
            name: .NSMetadataQueryDidFinishGathering,
            object: metadataQuery
        )

        metadataQuery.start()
        query = metadataQuery
        isMonitoring = true
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        query?.stop()
        query?.disableUpdates()
        NotificationCenter.default.removeObserver(self)
        query = nil
        isMonitoring = false
    }

    // MARK: - Query Callbacks

    @objc private func queryDidFinishGathering(_ notification: Notification) {
        processQueryResults()
    }

    @objc private func queryDidUpdate(_ notification: Notification) {
        processQueryResults()
    }

    private func processQueryResults() {
        guard let query else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }

        let items = (0..<query.resultCount).compactMap { query.result(at: $0) as? NSMetadataItem }
        backupsDidChange.send(items)
    }
}
