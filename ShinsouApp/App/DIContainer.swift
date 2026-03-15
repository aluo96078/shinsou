import Foundation
import ShinsouData
import ShinsouDomain
import ShinsouSourceAPI
import ShinsouSourceLocal
import GRDB

/// Lightweight dependency injection container.
/// Registers all dependencies at app startup.
@MainActor
final class DIContainer: ObservableObject {
    static let shared = DIContainer()

    /// CloudKit 同步用的 TransactionObserver（需保持強引用）
    private var syncObserver: SyncTransactionObserver?

    // MARK: - Data Layer
    lazy var database: DatabaseManager = {
        do {
            return try DatabaseManager()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }()

    lazy var preferences: AppPreferences = AppPreferences()

    // MARK: - Sources
    lazy var localSource: LocalSource = LocalSource()
    lazy var sourceManager: SourceManager = SourceManager.shared
    lazy var extensionManager: ExtensionManager = ExtensionManager.shared

    // MARK: - Repositories (lazily initialized)
    lazy var mangaRepository: MangaRepository = MangaRepositoryImpl(databaseManager: database)
    lazy var chapterRepository: ChapterRepository = ChapterRepositoryImpl(databaseManager: database)
    lazy var categoryRepository: CategoryRepository = CategoryRepositoryImpl(databaseManager: database)
    lazy var trackRepository: TrackRepository = TrackRepositoryImpl(databaseManager: database)
    lazy var historyRepository: HistoryRepository = HistoryRepositoryImpl(databaseManager: database)
    lazy var extensionRepoRepository: ExtensionRepoRepository = ExtensionRepoRepositoryImpl(databaseManager: database)
    lazy var updatesRepository: UpdatesRepository = UpdatesRepositoryImpl(databaseManager: database)

    private init() {}

    /// 啟用 CloudKit 同步的 DB 變更監聽。
    func enableSyncObserver() {
        guard syncObserver == nil else { return }
        let observer = SyncTransactionObserver()
        database.dbPool.add(transactionObserver: observer)
        syncObserver = observer
    }

    /// 停用 CloudKit 同步的 DB 變更監聽。
    func disableSyncObserver() {
        if let observer = syncObserver {
            database.dbPool.remove(transactionObserver: observer)
            syncObserver = nil
        }
    }
}
