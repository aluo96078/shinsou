import Foundation
import WebKit

/// Centralized cookie manager that bridges HTTPCookieStorage and WKWebView cookies.
/// Supports both global (shared) cookies and per-source isolated cookie jars.
/// Per-source cookies are persisted to UserDefaults so they survive app restarts.
final class CookieManager {
    static let shared = CookieManager()

    private let storage = HTTPCookieStorage.shared

    /// Per-source cookie jars, keyed by sourceId.
    /// Loaded lazily from UserDefaults and written back on mutation.
    private var sourceCookieJars: [Int64: [HTTPCookie]] = [:]
    private let jarLock = NSLock()

    private init() {
        // Accept all cookies by default
        storage.cookieAcceptPolicy = .always
    }

    // MARK: - Cookie retrieval (global)

    /// Get all cookies for a URL, formatted as a Cookie header value.
    func cookieHeader(for url: URL) -> String? {
        guard let cookies = storage.cookies(for: url), !cookies.isEmpty else {
            return nil
        }
        return HTTPCookie.requestHeaderFields(with: cookies)["Cookie"]
    }

    /// Get all cookies for a URL.
    func cookies(for url: URL) -> [HTTPCookie] {
        storage.cookies(for: url) ?? []
    }

    /// Check if a Cloudflare clearance cookie exists for a URL.
    func hasCloudflareToken(for url: URL) -> Bool {
        let cookies = storage.cookies(for: url) ?? []
        return cookies.contains { $0.name == "cf_clearance" }
    }

    // MARK: - Cookie management (global + per-source)

    /// Apply cookies to a URLRequest.
    /// When sourceId is provided, per-source cookies are merged (and take priority over global).
    func applyCookies(to request: inout URLRequest, sourceId: Int64? = nil) {
        guard let url = request.url else { return }

        // Start with global cookies
        var cookieParts: [String] = []
        if let globalValue = cookieHeader(for: url) {
            cookieParts.append(globalValue)
        }

        // Merge per-source cookies (override global for same-name cookies)
        if let sourceId {
            let srcCookies = getSourceCookies(sourceId: sourceId, for: url)
            if !srcCookies.isEmpty {
                let srcHeader = HTTPCookie.requestHeaderFields(with: srcCookies)["Cookie"]
                if let srcHeader, !srcHeader.isEmpty {
                    cookieParts.append(srcHeader)
                }
            }
        }

        if !cookieParts.isEmpty {
            let combined = cookieParts.joined(separator: "; ")
            if let existing = request.value(forHTTPHeaderField: "Cookie"), !existing.isEmpty {
                request.setValue(existing + "; " + combined, forHTTPHeaderField: "Cookie")
            } else {
                request.setValue(combined, forHTTPHeaderField: "Cookie")
            }
        }
    }

    /// Store cookies from an HTTP response.
    /// When sourceId is provided, cookies are also saved to the per-source jar.
    func storeCookies(from response: URLResponse, for url: URL, sourceId: Int64? = nil) {
        guard let httpResponse = response as? HTTPURLResponse,
              let headerFields = httpResponse.allHeaderFields as? [String: String] else {
            return
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)

        // Always store in global storage
        for cookie in cookies {
            storage.setCookie(cookie)
        }

        // Also store in per-source jar if sourceId provided
        if let sourceId, !cookies.isEmpty {
            addToSourceJar(sourceId: sourceId, cookies: cookies)
        }
    }

    /// Sync cookies from WKWebView to HTTPCookieStorage.
    func syncFromWebView(for url: URL) async {
        let wkStore = WKWebsiteDataStore.default().httpCookieStore
        let allCookies = await wkStore.allCookies()
        let host = url.host ?? ""

        for cookie in allCookies {
            if cookie.domain.contains(host) || host.contains(cookie.domain.replacingOccurrences(of: ".", with: "", options: .anchored)) {
                storage.setCookie(cookie)
            }
        }
    }

    /// Delete cookies for a specific host.
    func deleteCookies(for host: String) {
        guard let cookies = storage.cookies else { return }
        for cookie in cookies where cookie.domain.contains(host) {
            storage.deleteCookie(cookie)
        }
    }

    // MARK: - Per-source cookie jar

    /// Get all per-source cookies matching a URL.
    func getSourceCookies(sourceId: Int64, for url: URL) -> [HTTPCookie] {
        let jar = loadSourceJar(sourceId: sourceId)
        let host = url.host ?? ""
        let path = url.path.isEmpty ? "/" : url.path
        let now = Date()

        return jar.filter { cookie in
            // Domain matching
            let domain = cookie.domain
            let domainMatch = host == domain
                || host.hasSuffix(domain)
                || host.hasSuffix("." + domain)
                || domain.hasPrefix(".") && host.hasSuffix(String(domain.dropFirst()))

            // Path matching
            let pathMatch = path.hasPrefix(cookie.path)

            // Expiry check (nil = session cookie, keep alive)
            let notExpired = cookie.expiresDate == nil || cookie.expiresDate! > now

            return domainMatch && pathMatch && notExpired
        }
    }

    /// Get all per-source cookies (unfiltered).
    func getAllSourceCookies(sourceId: Int64) -> [HTTPCookie] {
        loadSourceJar(sourceId: sourceId)
    }

    /// Get a specific cookie by name for a source.
    func getSourceCookie(sourceId: Int64, name: String, url: URL) -> HTTPCookie? {
        getSourceCookies(sourceId: sourceId, for: url).first { $0.name == name }
    }

    /// Set a cookie in the per-source jar.
    func setSourceCookie(sourceId: Int64, cookie: HTTPCookie) {
        addToSourceJar(sourceId: sourceId, cookies: [cookie])
        // Also add to global storage so URLSession picks it up
        storage.setCookie(cookie)
    }

    /// Clear all cookies for a specific source.
    func clearSourceCookies(sourceId: Int64) {
        jarLock.lock()
        sourceCookieJars[sourceId] = []
        jarLock.unlock()
        persistSourceJar(sourceId: sourceId, cookies: [])
    }

    /// Delete a specific cookie by name from a source jar.
    func deleteSourceCookie(sourceId: Int64, name: String, domain: String) {
        jarLock.lock()
        var jar = sourceCookieJars[sourceId] ?? loadSourceJarFromDisk(sourceId: sourceId)
        jar.removeAll { $0.name == name && $0.domain == domain }
        sourceCookieJars[sourceId] = jar
        jarLock.unlock()
        persistSourceJar(sourceId: sourceId, cookies: jar)
    }

    // MARK: - Per-source jar persistence

    private func loadSourceJar(sourceId: Int64) -> [HTTPCookie] {
        jarLock.lock()
        defer { jarLock.unlock() }

        if let cached = sourceCookieJars[sourceId] {
            return cached
        }
        let jar = loadSourceJarFromDisk(sourceId: sourceId)
        sourceCookieJars[sourceId] = jar
        return jar
    }

    private func addToSourceJar(sourceId: Int64, cookies: [HTTPCookie]) {
        jarLock.lock()
        var jar = sourceCookieJars[sourceId] ?? loadSourceJarFromDisk(sourceId: sourceId)
        for newCookie in cookies {
            // Remove existing cookie with same name+domain+path, then add new one
            jar.removeAll { $0.name == newCookie.name && $0.domain == newCookie.domain && $0.path == newCookie.path }
            jar.append(newCookie)
        }
        sourceCookieJars[sourceId] = jar
        jarLock.unlock()
        persistSourceJar(sourceId: sourceId, cookies: jar)
    }

    private func loadSourceJarFromDisk(sourceId: Int64) -> [HTTPCookie] {
        let key = "source.\(sourceId).cookies"
        guard let array = UserDefaults.standard.array(forKey: key) as? [[String: Any]] else {
            return []
        }
        return array.compactMap { dict in
            // Convert stored [String: Any] back to HTTPCookiePropertyKey dict
            var props: [HTTPCookiePropertyKey: Any] = [:]
            for (k, v) in dict {
                props[HTTPCookiePropertyKey(k)] = v
            }
            return HTTPCookie(properties: props)
        }
    }

    private func persistSourceJar(sourceId: Int64, cookies: [HTTPCookie]) {
        let key = "source.\(sourceId).cookies"
        if cookies.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        // Serialize cookies as an array of property dictionaries
        let array: [[String: Any]] = cookies.compactMap { cookie in
            var dict: [String: Any] = [:]
            dict[HTTPCookiePropertyKey.name.rawValue] = cookie.name
            dict[HTTPCookiePropertyKey.value.rawValue] = cookie.value
            dict[HTTPCookiePropertyKey.domain.rawValue] = cookie.domain
            dict[HTTPCookiePropertyKey.path.rawValue] = cookie.path
            if cookie.isSecure {
                dict[HTTPCookiePropertyKey.secure.rawValue] = "TRUE"
            }
            if cookie.isHTTPOnly {
                dict["HttpOnly"] = "TRUE"
            }
            if let expires = cookie.expiresDate {
                dict[HTTPCookiePropertyKey.expires.rawValue] = expires.timeIntervalSince1970
            }
            return dict
        }
        UserDefaults.standard.set(array, forKey: key)
    }
}
