import Foundation

/// Provides rotating User-Agent strings to mimic real browser traffic.
/// Modeled after Shinsou's UserAgentInterceptor but with UA rotation.
final class UserAgentProvider {
    static let shared = UserAgentProvider()

    /// Pool of realistic mobile browser User-Agent strings.
    private let userAgents: [String] = [
        // iOS Safari (various versions)
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_3_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3.1 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1",

        // Android Chrome
        "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.6261.64 Mobile Safari/537.36",
        "Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.6167.178 Mobile Safari/537.36",
        "Mozilla/5.0 (Linux; Android 13; SM-A546B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.230 Mobile Safari/537.36",
        "Mozilla/5.0 (Linux; Android 14; Pixel 7a) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.6312.40 Mobile Safari/537.36",
        "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36",

        // Desktop Chrome (some sites block mobile UA)
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",

        // Desktop Firefox
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:123.0) Gecko/20100101 Firefox/123.0",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:123.0) Gecko/20100101 Firefox/123.0",
    ]

    /// Per-host UA assignment — each host gets a sticky UA for the session to avoid suspicion.
    private var hostAssignments: [String: String] = [:]
    private let lock = NSLock()

    private init() {}

    /// Get a User-Agent for the given host.
    /// The same host always gets the same UA within a session (to avoid mid-session fingerprint changes).
    func userAgent(for host: String) -> String {
        lock.lock()
        defer { lock.unlock() }

        if let existing = hostAssignments[host] {
            return existing
        }

        let ua = userAgents.randomElement()!
        hostAssignments[host] = ua
        return ua
    }

    /// Get a random User-Agent (for cases where host is unknown).
    var randomUserAgent: String {
        userAgents.randomElement()!
    }

    /// Reset all host assignments (e.g. on app restart or manual refresh).
    func resetAssignments() {
        lock.lock()
        defer { lock.unlock() }
        hostAssignments.removeAll()
    }
}
