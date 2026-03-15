import Foundation
import SwiftUI

// MARK: - DeepLink

/// Represents all supported deep link destinations in Shinsou.
///
/// Supported URL scheme: `shinsou://`
///
/// Examples:
/// - `shinsou://manga/12345`
/// - `shinsou://chapter/67890`
/// - `shinsou://library`
/// - `shinsou://updates`
/// - `shinsou://source/99999`
enum DeepLink: Equatable {
    case manga(id: Int64)
    case chapter(id: Int64)
    case library
    case updates
    case source(id: Int64)

    // MARK: - URL Parsing

    init?(url: URL) {
        guard url.scheme == "shinsou" else { return nil }

        let host = url.host()
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "manga":
            guard let idStr = pathComponents.first, let id = Int64(idStr) else { return nil }
            self = .manga(id: id)

        case "chapter":
            guard let idStr = pathComponents.first, let id = Int64(idStr) else { return nil }
            self = .chapter(id: id)

        case "library":
            self = .library

        case "updates":
            self = .updates

        case "source":
            guard let idStr = pathComponents.first, let id = Int64(idStr) else { return nil }
            self = .source(id: id)

        default:
            return nil
        }
    }

    // MARK: - URL Generation

    /// Generates the canonical URL for this deep link.
    var url: URL {
        switch self {
        case .manga(let id):
            return URL(string: "shinsou://manga/\(id)")!
        case .chapter(let id):
            return URL(string: "shinsou://chapter/\(id)")!
        case .library:
            return URL(string: "shinsou://library")!
        case .updates:
            return URL(string: "shinsou://updates")!
        case .source(let id):
            return URL(string: "shinsou://source/\(id)")!
        }
    }
}

// MARK: - DeepLinkHandler

/// Centralised deep link router.
///
/// Usage in your `App` scene:
/// ```swift
/// .onOpenURL { url in
///     DeepLinkHandler.shared.handle(url: url)
/// }
/// ```
///
/// Consuming views observe `pendingDeepLink` and clear it once navigated:
/// ```swift
/// .onChange(of: DeepLinkHandler.shared.pendingDeepLink) { link in
///     guard let link else { return }
///     // navigate...
///     DeepLinkHandler.shared.consume()
/// }
/// ```
@MainActor
final class DeepLinkHandler: ObservableObject {

    // MARK: - Shared

    static let shared = DeepLinkHandler()

    // MARK: - State

    /// The most recently received deep link that has not yet been consumed by a view.
    @Published var pendingDeepLink: DeepLink?

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Parses `url` and stores it as a pending deep link if valid.
    /// Invalid or unsupported URLs are silently ignored.
    func handle(url: URL) {
        guard let deepLink = DeepLink(url: url) else {
            return
        }
        pendingDeepLink = deepLink
    }

    /// Marks the current pending deep link as consumed, clearing it.
    /// Call this after you have navigated to the destination.
    func consume() {
        pendingDeepLink = nil
    }
}
