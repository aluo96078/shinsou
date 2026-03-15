import Foundation
import Combine

// MARK: - IncognitoManager

/// Manages the app-wide incognito mode.
///
/// When incognito mode is active:
/// - Reading history is **not** persisted.
/// - Recently-read chapters are **not** updated in the library.
/// - No tracker updates are sent (e.g. AniList, MyAnimeList).
///
/// The state is persisted across launches via `UserDefaults` so the user's
/// preference is remembered, but callers should observe `isIncognito` via
/// Combine or SwiftUI `@ObservedObject` to react to runtime changes.
final class IncognitoManager: ObservableObject {

    // MARK: - Shared Instance

    static let shared = IncognitoManager()

    // MARK: - Constants

    private enum Keys {
        static let incognitoMode = "settings.security.incognitoMode"
    }

    // MARK: - Published State

    /// `true` when incognito mode is currently active.
    @Published var isIncognito: Bool {
        didSet {
            guard oldValue != isIncognito else { return }
            UserDefaults.standard.set(isIncognito, forKey: Keys.incognitoMode)
            postChangeNotification()
        }
    }

    // MARK: - Init

    init() {
        isIncognito = UserDefaults.standard.bool(forKey: Keys.incognitoMode)
    }

    // MARK: - Public API

    /// Toggle incognito mode on or off.
    func toggle() {
        isIncognito.toggle()
    }

    /// Enable incognito mode explicitly.
    func enable() {
        isIncognito = true
    }

    /// Disable incognito mode explicitly.
    func disable() {
        isIncognito = false
    }

    // MARK: - Private Helpers

    private func postChangeNotification() {
        NotificationCenter.default.post(
            name: .incognitoModeDidChange,
            object: nil,
            userInfo: [Notification.incognitoModeKey: isIncognito]
        )
    }
}

// MARK: - Notification Support

extension Notification.Name {
    /// Posted on the default `NotificationCenter` whenever incognito mode is toggled.
    /// `userInfo` contains `Notification.incognitoModeKey` → `Bool`.
    static let incognitoModeDidChange = Notification.Name("incognitoModeDidChange")
}

extension Notification {
    /// Key used in `userInfo` for `incognitoModeDidChange` notifications.
    static let incognitoModeKey = "isIncognito"
}
