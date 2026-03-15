import Foundation
import WebKit

/// Centralized cookie manager that bridges HTTPCookieStorage and WKWebView cookies.
/// Ensures Cloudflare cf_clearance and other session cookies persist across requests.
final class CookieManager {
    static let shared = CookieManager()

    private let storage = HTTPCookieStorage.shared

    private init() {
        // Accept all cookies by default
        storage.cookieAcceptPolicy = .always
    }

    // MARK: - Cookie retrieval

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

    // MARK: - Cookie management

    /// Apply cookies to a URLRequest.
    func applyCookies(to request: inout URLRequest) {
        guard let url = request.url else { return }
        if let cookieValue = cookieHeader(for: url) {
            // Merge with existing Cookie header if present
            if let existing = request.value(forHTTPHeaderField: "Cookie"), !existing.isEmpty {
                request.setValue(existing + "; " + cookieValue, forHTTPHeaderField: "Cookie")
            } else {
                request.setValue(cookieValue, forHTTPHeaderField: "Cookie")
            }
        }
    }

    /// Store cookies from an HTTP response.
    func storeCookies(from response: URLResponse, for url: URL) {
        guard let httpResponse = response as? HTTPURLResponse,
              let headerFields = httpResponse.allHeaderFields as? [String: String] else {
            return
        }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        for cookie in cookies {
            storage.setCookie(cookie)
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
}
