import Foundation
import MihonData
import MihonDomain
import MihonSourceAPI
import MihonSourceLocal

/// Lightweight dependency injection container.
/// Registers all dependencies at app startup.
@MainActor
final class DIContainer: ObservableObject {
    static let shared = DIContainer()

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
}
