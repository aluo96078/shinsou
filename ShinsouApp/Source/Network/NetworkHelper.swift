import Foundation

/// Centralized network helper modeled after Shinsou's NetworkHelper.
/// Provides a shared URLSession with anti-scraping features:
/// - Per-host rate limiting (token bucket)
/// - User-Agent rotation (per-host sticky)
/// - Cookie persistence (Cloudflare cf_clearance etc.)
/// - Cloudflare Workers proxy forwarding
/// - Configurable cache and timeouts
final class NetworkHelper {
    static let shared = NetworkHelper()

    /// URLSession with caching enabled (for general requests)
    let session: URLSession

    /// URLSession without caching (for pagination / dynamic content)
    let cachelessSession: URLSession

    let rateLimiterRegistry = RateLimiterRegistry.shared
    let userAgentProvider = UserAgentProvider.shared
    let cookieManager = CookieManager.shared

    // MARK: - Proxy configuration (read from UserDefaults)

    /// Whether the Cloudflare Workers proxy is enabled.
    var isProxyEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.proxyEnabled)
    }

    /// The Cloudflare Worker URL (e.g. https://shinsou-proxy.user.workers.dev)
    var proxyWorkerUrl: String? {
        let url = UserDefaults.standard.string(forKey: SettingsKeys.proxyWorkerUrl)
        guard let url, !url.isEmpty else { return nil }
        return url.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// Optional API key for the Worker.
    var proxyApiKey: String? {
        let key = UserDefaults.standard.string(forKey: SettingsKeys.proxyApiKey)
        guard let key, !key.isEmpty else { return nil }
        return key
    }

    private init() {
        // Cached session — 5 MiB cache, 10 min maxAge
        let cachedConfig = URLSessionConfiguration.default
        cachedConfig.timeoutIntervalForRequest = 30
        cachedConfig.timeoutIntervalForResource = 120
        cachedConfig.urlCache = URLCache(
            memoryCapacity: 2 * 1024 * 1024,   // 2 MiB memory
            diskCapacity: 5 * 1024 * 1024,      // 5 MiB disk
            diskPath: "shinsou_network_cache"
        )
        cachedConfig.requestCachePolicy = .useProtocolCachePolicy
        self.session = URLSession(configuration: cachedConfig)

        // Cacheless session — for requests that need fresh data
        let noCacheConfig = URLSessionConfiguration.default
        noCacheConfig.timeoutIntervalForRequest = 30
        noCacheConfig.timeoutIntervalForResource = 120
        noCacheConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        noCacheConfig.urlCache = nil
        self.cachelessSession = URLSession(configuration: noCacheConfig)
    }

    // MARK: - Proxy URL rewriting

    /// Rewrite a target URL to go through the Cloudflare Worker proxy.
    /// Returns the original URL if proxy is disabled or not configured.
    private func proxyUrl(for targetUrl: String) -> URL? {
        guard isProxyEnabled,
              let workerBase = proxyWorkerUrl,
              let encoded = targetUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(workerBase)/?url=\(encoded)") else {
            return URL(string: targetUrl)
        }
        return url
    }

    /// Apply proxy authentication headers if configured.
    private func applyProxyHeaders(to request: inout URLRequest) {
        guard isProxyEnabled else { return }
        if let apiKey = proxyApiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-Proxy-Key")
        }
    }

    // MARK: - Synchronous request (for JSBridge usage on background threads)

    /// Perform a synchronous GET request with all anti-scraping features applied.
    /// - Parameters:
    ///   - url: The URL string to fetch.
    ///   - headers: Additional headers from the plugin.
    ///   - useCache: Whether to use cached responses.
    /// - Returns: The response body as a String, or nil on error.
    func syncGet(url urlString: String, headers: [String: String] = [:], useCache: Bool = false) -> (String?, Error?) {
        guard let originalUrl = URL(string: urlString) else {
            return (nil, URLError(.badURL))
        }

        let host = originalUrl.host ?? "unknown"

        // 1. Rate limiting — block until permit available
        rateLimiterRegistry.limiter(for: host).acquire()

        // 2. Build request — route through proxy if enabled
        let requestUrl = proxyUrl(for: urlString) ?? originalUrl
        var request = URLRequest(url: requestUrl)
        request.cachePolicy = useCache ? .useProtocolCachePolicy : .reloadIgnoringLocalCacheData

        // 3. User-Agent rotation (set first, allow plugin headers to override)
        request.setValue(userAgentProvider.userAgent(for: host), forHTTPHeaderField: "User-Agent")

        // 4. Standard browser headers
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        // 5. Apply plugin-specific headers (may override UA, Accept, etc.)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // 6. Apply proxy authentication
        applyProxyHeaders(to: &request)

        // 7. Apply persisted cookies (Cloudflare cf_clearance, etc.)
        cookieManager.applyCookies(to: &request)

        // 8. Execute request synchronously
        let sem = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultResponse: URLResponse?
        var resultError: Error?

        let urlSession = useCache ? session : cachelessSession

        urlSession.dataTask(with: request) { data, response, error in
            resultData = data
            resultResponse = response
            resultError = error
            sem.signal()
        }.resume()
        sem.wait()

        // 9. Store response cookies (use original URL for cookie domain matching)
        if let response = resultResponse {
            cookieManager.storeCookies(from: response, for: originalUrl)
        }

        // 10. Return result
        if let data = resultData, let str = String(data: data, encoding: .utf8) {
            return (str, nil)
        }
        return (nil, resultError)
    }

    /// Perform a synchronous POST request with all anti-scraping features applied.
    func syncPost(url urlString: String, body: String, headers: [String: String] = [:]) -> (String?, Error?) {
        guard let originalUrl = URL(string: urlString) else {
            return (nil, URLError(.badURL))
        }

        let host = originalUrl.host ?? "unknown"

        // 1. Rate limiting
        rateLimiterRegistry.limiter(for: host).acquire()

        // 2. Build request — route through proxy if enabled
        let requestUrl = proxyUrl(for: urlString) ?? originalUrl
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        // 3. User-Agent
        request.setValue(userAgentProvider.userAgent(for: host), forHTTPHeaderField: "User-Agent")

        // 4. Standard headers
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // 5. Plugin headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // 6. Proxy authentication
        applyProxyHeaders(to: &request)

        // 7. Cookies
        cookieManager.applyCookies(to: &request)

        // 8. Execute
        let sem = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultResponse: URLResponse?
        var resultError: Error?

        cachelessSession.dataTask(with: request) { data, response, error in
            resultData = data
            resultResponse = response
            resultError = error
            sem.signal()
        }.resume()
        sem.wait()

        // 9. Store cookies (use original URL)
        if let response = resultResponse {
            cookieManager.storeCookies(from: response, for: originalUrl)
        }

        if let data = resultData, let str = String(data: data, encoding: .utf8) {
            return (str, nil)
        }
        return (nil, resultError)
    }

    // MARK: - Async request (for Swift async/await usage)

    /// Perform an async GET request with all anti-scraping features applied.
    func asyncGet(url urlString: String, headers: [String: String] = [:]) async throws -> (Data, URLResponse) {
        guard let originalUrl = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let host = originalUrl.host ?? "unknown"

        // Rate limiting on background thread
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().async {
                self.rateLimiterRegistry.limiter(for: host).acquire()
                continuation.resume()
            }
        }

        let requestUrl = proxyUrl(for: urlString) ?? originalUrl
        var request = URLRequest(url: requestUrl)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(userAgentProvider.userAgent(for: host), forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        applyProxyHeaders(to: &request)
        cookieManager.applyCookies(to: &request)

        let (data, response) = try await cachelessSession.data(for: request)
        cookieManager.storeCookies(from: response, for: originalUrl)
        return (data, response)
    }

    // MARK: - Image proxy support

    /// Build a URLRequest for loading images through the proxy (if enabled).
    /// Used by Nuke / ImagePipeline to route image downloads through Cloudflare Workers.
    func imageURLRequest(for urlString: String, headers: [String: String] = [:], referer: String? = nil) -> URLRequest? {
        guard let originalUrl = URL(string: urlString)
                ?? URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString) else {
            return nil
        }

        let requestUrl = proxyUrl(for: urlString) ?? originalUrl
        var request = URLRequest(url: requestUrl)

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
            request.setValue(referer, forHTTPHeaderField: "Origin")
        }

        applyProxyHeaders(to: &request)

        return request
    }

    // MARK: - Rate limit configuration

    // Note: See ImageRequest+Proxy extension below for Nuke integration.

    /// Register a custom rate limit for a specific host.
    /// Call this during plugin initialization if the plugin specifies rate limits.
    func setRateLimit(host: String, permits: Int, period: TimeInterval) {
        rateLimiterRegistry.register(host: host, permits: permits, period: period)
    }
}

// MARK: - Nuke ImageRequest proxy extension

import Nuke

extension ImageRequest {
    /// Create an ImageRequest that routes through the Cloudflare Workers proxy if enabled.
    static func proxied(url: URL, headers: [String: String] = [:], referer: String? = nil) -> ImageRequest {
        if let req = NetworkHelper.shared.imageURLRequest(for: url.absoluteString, headers: headers, referer: referer) {
            return ImageRequest(urlRequest: req)
        }
        return ImageRequest(url: url)
    }
}
