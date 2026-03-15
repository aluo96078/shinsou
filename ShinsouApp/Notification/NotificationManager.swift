import Foundation
import UserNotifications

// MARK: - NotificationManager

/// Manages all local notification scheduling for Shinsou.
///
/// Responsibilities:
/// - Request user permission for notifications.
/// - Register UNNotificationCategory objects with custom actions.
/// - Schedule notifications for library updates, downloads, and backups.
final class NotificationManager: @unchecked Sendable {

    // MARK: - Shared

    static let shared = NotificationManager()

    // MARK: - Category identifiers

    enum Category: String {
        case libraryUpdate = "LIBRARY_UPDATE"
        case download      = "DOWNLOAD"
        case backup        = "BACKUP"
    }

    // MARK: - Action identifiers

    private enum Action: String {
        case viewUpdates  = "VIEW_UPDATES"
        case openReader   = "OPEN_READER"
        case openBackup   = "OPEN_BACKUP"
    }

    // MARK: - Init

    private init() {}

    // MARK: - Permission

    /// Requests notification authorisation from the user.
    /// - Returns: `true` if the user granted permission, `false` otherwise.
    @discardableResult
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    // MARK: - Category Registration

    /// Registers notification categories with interactive actions.
    /// Call once at app startup (e.g. in `AppDelegate.didFinishLaunching`).
    func registerCategories() {
        let center = UNUserNotificationCenter.current()

        // Library Update category
        let viewUpdatesAction = UNNotificationAction(
            identifier: Action.viewUpdates.rawValue,
            title: "View Updates",
            options: .foreground
        )
        let libraryCategory = UNNotificationCategory(
            identifier: Category.libraryUpdate.rawValue,
            actions: [viewUpdatesAction],
            intentIdentifiers: [],
            options: []
        )

        // Download category
        let openReaderAction = UNNotificationAction(
            identifier: Action.openReader.rawValue,
            title: "Read Now",
            options: .foreground
        )
        let downloadCategory = UNNotificationCategory(
            identifier: Category.download.rawValue,
            actions: [openReaderAction],
            intentIdentifiers: [],
            options: []
        )

        // Backup category
        let openBackupAction = UNNotificationAction(
            identifier: Action.openBackup.rawValue,
            title: "View Backups",
            options: .foreground
        )
        let backupCategory = UNNotificationCategory(
            identifier: Category.backup.rawValue,
            actions: [openBackupAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([libraryCategory, downloadCategory, backupCategory])
    }

    // MARK: - Library Update Notification

    /// Schedules a notification summarising new chapters found during a library update.
    /// - Parameters:
    ///   - newChapters: Total number of new chapters found.
    ///   - mangaTitles: The titles of manga that received new chapters (first 3 shown).
    func notifyLibraryUpdate(newChapters: Int, mangaTitles: [String]) {
        guard newChapters > 0 else { return }

        let content = UNMutableNotificationContent()
        content.categoryIdentifier = Category.libraryUpdate.rawValue
        content.sound = .default

        if newChapters == 1, let title = mangaTitles.first {
            content.title = title
            content.body = "1 new chapter available"
        } else {
            content.title = "Library Updated"
            let preview = mangaTitles.prefix(3).joined(separator: ", ")
            let suffix = mangaTitles.count > 3 ? " and \(mangaTitles.count - 3) more" : ""
            content.body = "\(newChapters) new chapters in \(preview)\(suffix)"
        }

        schedule(content: content, identifier: "library-update")
    }

    // MARK: - Download Notification

    /// Schedules a notification when a chapter download completes.
    /// - Parameters:
    ///   - mangaTitle: The title of the manga.
    ///   - chapterName: The name of the downloaded chapter.
    func notifyDownloadComplete(mangaTitle: String, chapterName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Download Complete"
        content.body = "\(mangaTitle) — \(chapterName)"
        content.sound = .default
        content.categoryIdentifier = Category.download.rawValue

        // Use a unique identifier so multiple download notifications don't collapse
        let identifier = "download-\(mangaTitle)-\(chapterName)".replacingOccurrences(of: " ", with: "-")
        schedule(content: content, identifier: identifier)
    }

    // MARK: - Backup Notification

    /// Schedules a notification when a backup operation completes.
    /// - Parameter path: The file path (or file name) of the completed backup.
    func notifyBackupComplete(path: String) {
        let content = UNMutableNotificationContent()
        content.title = "Backup Complete"
        let filename = URL(fileURLWithPath: path).lastPathComponent
        content.body = "Saved: \(filename)"
        content.sound = .default
        content.categoryIdentifier = Category.backup.rawValue

        schedule(content: content, identifier: "backup-complete")
    }

    // MARK: - Helpers

    private func schedule(content: UNMutableNotificationContent, identifier: String) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                // Non-fatal — silently log in debug builds
                #if DEBUG
                print("[NotificationManager] Failed to schedule '\(identifier)': \(error.localizedDescription)")
                #endif
            }
        }
    }
}
