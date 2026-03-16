import Foundation
import JavaScriptCore
import SwiftSoup
import ShinsouSourceAPI

/// Protocol for JS-accessible methods
@objc protocol JSBridgeExports: JSExport {
    // HTTP
    func httpGet(_ url: String) -> JSValue
    func httpGetWithHeaders(_ url: String, _ headers: JSValue) -> JSValue
    func httpPost(_ url: String, _ body: String, _ headers: JSValue) -> JSValue

    // DOM — handle-based API backed by SwiftSoup
    func htmlParse(_ html: String) -> Int
    func htmlParseFragment(_ html: String, _ baseUri: String) -> Int
    func domSelect(_ handleId: Int, _ cssSelector: String) -> JSValue
    func domFirst(_ handleId: Int, _ cssSelector: String) -> Int
    func domText(_ handleId: Int) -> String
    func domOwnText(_ handleId: Int) -> String
    func domHtml(_ handleId: Int) -> String
    func domOuterHtml(_ handleId: Int) -> String
    func domAttr(_ handleId: Int, _ attrName: String) -> String
    func domHasAttr(_ handleId: Int, _ attrName: String) -> Bool
    func domAbsUrl(_ handleId: Int, _ attrName: String) -> String
    func domTagName(_ handleId: Int) -> String
    func domClassName(_ handleId: Int) -> String
    func domId(_ handleId: Int) -> String
    func domChildren(_ handleId: Int) -> JSValue
    func domParent(_ handleId: Int) -> Int
    func domNextSibling(_ handleId: Int) -> Int
    func domPrevSibling(_ handleId: Int) -> Int
    func domRemove(_ handleId: Int)
    func domRelease(_ handleId: Int)
    func domReleaseAll()

    // Logging
    func log(_ message: String)

    // Preferences (per-source, persisted to UserDefaults)
    func getPreference(_ key: String) -> String?
    func setPreference(_ key: String, _ value: String)

    // Credentials (per-source login, persisted to UserDefaults)
    func getCredentialUsername() -> String?
    func getCredentialPassword() -> String?
    func setCredential(_ username: String, _ password: String)
    func clearCredential()
    func hasCredential() -> Bool

    // Cookies (per-source, persisted)
    func getCookie(_ name: String, _ url: String) -> String?
    func getCookies(_ url: String) -> JSValue
    func setCookie(_ name: String, _ value: String, _ domain: String, _ path: String, _ expirySeconds: Int) -> Bool
    func deleteCookie(_ name: String, _ domain: String)
    func clearCookies()

    // Legacy compatibility
    func parseHtml(_ html: String, _ selector: String) -> JSValue
}

/// Bridge object that provides native capabilities to JS plugins
@objc class JSBridge: NSObject, JSBridgeExports {
    weak var context: JSContext?

    /// Source ID for per-source network overrides and credential storage.
    var sourceId: Int64 = 0

    /// Handle store — maps integer IDs to SwiftSoup nodes
    private var handleCounter: Int = 0
    private var handles: [Int: SwiftSoup.Node] = [:]

    /// Optional: custom headers to attach to every HTTP request (e.g. User-Agent, Referer)
    var defaultHeaders: [String: String] = [
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    ]

    /// Plugin log messages accumulated during JS execution (thread-safe with JS calls).
    private(set) var pluginLogs: [String] = []

    /// Clear accumulated plugin logs (call before each JS invocation).
    func clearPluginLogs() {
        pluginLogs.removeAll()
    }

    init(context: JSContext) {
        self.context = context
        super.init()
    }

    // MARK: - Handle management

    private func storeNode(_ node: SwiftSoup.Node) -> Int {
        handleCounter += 1
        handles[handleCounter] = node
        return handleCounter
    }

    private func getElement(_ handleId: Int) -> SwiftSoup.Element? {
        handles[handleId] as? SwiftSoup.Element
    }

    private func getNode(_ handleId: Int) -> SwiftSoup.Node? {
        handles[handleId]
    }

    // MARK: - HTTP

    /// Centralized network helper — handles rate limiting, UA rotation, cookies
    private let networkHelper = NetworkHelper.shared

    func httpGet(_ url: String) -> JSValue {
        return httpGetWithHeaders(url, JSValue(undefinedIn: context))
    }

    func httpGetWithHeaders(_ url: String, _ headers: JSValue) -> JSValue {
        guard let context else { return JSValue(undefinedIn: nil) }
        guard URL(string: url) != nil else {
            return JSValue(nullIn: context)
        }

        // Merge defaultHeaders with plugin-provided headers
        var mergedHeaders = defaultHeaders
        if let headerDict = headers.toDictionary() as? [String: String] {
            for (key, value) in headerDict {
                mergedHeaders[key] = value
            }
        }

        print("[JSBridge] GET \(url)")

        // Delegate to NetworkHelper — rate limiting, UA rotation, cookies, per-source DoH/proxy
        let (result, error) = networkHelper.syncGet(url: url, headers: mergedHeaders, sourceId: sourceId)

        if let str = result {
            return JSValue(object: str, in: context)
        }
        if let error {
            return JSValue(object: ["error": error.localizedDescription], in: context)
        }
        return JSValue(nullIn: context)
    }

    func httpPost(_ url: String, _ body: String, _ headers: JSValue) -> JSValue {
        guard let context else { return JSValue(undefinedIn: nil) }
        guard URL(string: url) != nil else {
            return JSValue(nullIn: context)
        }

        // Merge headers
        var mergedHeaders = defaultHeaders
        if let headerDict = headers.toDictionary() as? [String: String] {
            for (key, value) in headerDict {
                mergedHeaders[key] = value
            }
        }

        // Delegate to NetworkHelper — per-source DoH/proxy
        let (result, _) = networkHelper.syncPost(url: url, body: body, headers: mergedHeaders, sourceId: sourceId)

        if let str = result {
            return JSValue(object: str, in: context)
        }
        return JSValue(nullIn: context)
    }

    // MARK: - DOM API (handle-based, backed by SwiftSoup)

    /// Parse a full HTML document. Returns a handle ID for the Document.
    func htmlParse(_ html: String) -> Int {
        do {
            let doc = try SwiftSoup.parse(html)
            return storeNode(doc)
        } catch {
            log("htmlParse error: \(error)")
            return -1
        }
    }

    /// Parse an HTML fragment with a base URI. Returns a handle ID.
    func htmlParseFragment(_ html: String, _ baseUri: String) -> Int {
        do {
            let doc = try SwiftSoup.parse(html, baseUri)
            return storeNode(doc)
        } catch {
            log("htmlParseFragment error: \(error)")
            return -1
        }
    }

    /// Select elements by CSS selector. Returns an array of handle IDs.
    func domSelect(_ handleId: Int, _ cssSelector: String) -> JSValue {
        guard let context else { return JSValue(undefinedIn: nil) }
        guard let element = getElement(handleId) else {
            return JSValue(object: [Int](), in: context)
        }
        do {
            let elements = try element.select(cssSelector)
            let ids = elements.array().map { storeNode($0) }
            return JSValue(object: ids, in: context)
        } catch {
            log("domSelect error: \(error)")
            return JSValue(object: [Int](), in: context)
        }
    }

    /// Select the first element matching a CSS selector. Returns handle ID or -1.
    func domFirst(_ handleId: Int, _ cssSelector: String) -> Int {
        guard let element = getElement(handleId) else { return -1 }
        do {
            guard let first = try element.select(cssSelector).first() else { return -1 }
            return storeNode(first)
        } catch {
            return -1
        }
    }

    /// Get the combined text of this element and its children.
    func domText(_ handleId: Int) -> String {
        guard let element = getElement(handleId) else { return "" }
        return (try? element.text()) ?? ""
    }

    /// Get the text owned directly by this element (not child elements).
    func domOwnText(_ handleId: Int) -> String {
        guard let element = getElement(handleId) else { return "" }
        return element.ownText()
    }

    /// Get the inner HTML of this element.
    func domHtml(_ handleId: Int) -> String {
        guard let element = getElement(handleId) else { return "" }
        return (try? element.html()) ?? ""
    }

    /// Get the outer HTML of this element.
    func domOuterHtml(_ handleId: Int) -> String {
        guard let node = getNode(handleId) else { return "" }
        return (try? node.outerHtml()) ?? ""
    }

    /// Get an attribute value.
    func domAttr(_ handleId: Int, _ attrName: String) -> String {
        guard let element = getElement(handleId) else { return "" }
        return (try? element.attr(attrName)) ?? ""
    }

    /// Check if the element has an attribute.
    func domHasAttr(_ handleId: Int, _ attrName: String) -> Bool {
        guard let element = getElement(handleId) else { return false }
        return element.hasAttr(attrName)
    }

    /// Get the absolute URL for an attribute (resolves relative URLs against base URI).
    func domAbsUrl(_ handleId: Int, _ attrName: String) -> String {
        guard let element = getElement(handleId) else { return "" }
        return (try? element.absUrl(attrName)) ?? ""
    }

    /// Get the tag name.
    func domTagName(_ handleId: Int) -> String {
        guard let element = getElement(handleId) else { return "" }
        return element.tagName()
    }

    /// Get the class name(s).
    func domClassName(_ handleId: Int) -> String {
        guard let element = getElement(handleId) else { return "" }
        return (try? element.className()) ?? ""
    }

    /// Get the element's id attribute.
    func domId(_ handleId: Int) -> String {
        guard let element = getElement(handleId) else { return "" }
        return element.id()
    }

    /// Get child elements. Returns array of handle IDs.
    func domChildren(_ handleId: Int) -> JSValue {
        guard let context else { return JSValue(undefinedIn: nil) }
        guard let element = getElement(handleId) else {
            return JSValue(object: [Int](), in: context)
        }
        let ids = element.children().array().map { storeNode($0) }
        return JSValue(object: ids, in: context)
    }

    /// Get parent element. Returns handle ID or -1.
    func domParent(_ handleId: Int) -> Int {
        guard let element = getElement(handleId),
              let parent = element.parent() else { return -1 }
        return storeNode(parent)
    }

    /// Get next sibling element. Returns handle ID or -1.
    func domNextSibling(_ handleId: Int) -> Int {
        guard let element = getElement(handleId) else { return -1 }
        guard let next = try? element.nextElementSibling() else { return -1 }
        return storeNode(next)
    }

    /// Get previous sibling element. Returns handle ID or -1.
    func domPrevSibling(_ handleId: Int) -> Int {
        guard let element = getElement(handleId) else { return -1 }
        guard let prev = try? element.previousElementSibling() else { return -1 }
        return storeNode(prev)
    }

    /// Remove the element from the DOM tree.
    func domRemove(_ handleId: Int) {
        guard let element = getElement(handleId) else { return }
        try? element.remove()
    }

    /// Release a single handle (free memory).
    func domRelease(_ handleId: Int) {
        handles.removeValue(forKey: handleId)
    }

    /// Release all handles (call between page loads to prevent leaks).
    func domReleaseAll() {
        handles.removeAll()
        handleCounter = 0
    }

    // MARK: - Legacy compatibility

    func parseHtml(_ html: String, _ selector: String) -> JSValue {
        guard let context else { return JSValue(undefinedIn: nil) }
        do {
            let doc = try SwiftSoup.parse(html)
            let elements = try doc.select(selector)
            var results: [[String: String]] = []
            for el in elements.array() {
                results.append([
                    "text": (try? el.text()) ?? "",
                    "html": (try? el.html()) ?? "",
                    "outerHtml": (try? el.outerHtml()) ?? "",
                    "attr_href": (try? el.attr("href")) ?? "",
                    "attr_src": (try? el.attr("src")) ?? "",
                    "tagName": el.tagName()
                ])
            }
            return JSValue(object: results, in: context)
        } catch {
            return JSValue(object: html, in: context)
        }
    }

    // MARK: - Logging

    func log(_ message: String) {
        print("[JSPlugin] \(message)")
        pluginLogs.append(message)
    }

    // MARK: - Preferences (persisted to UserDefaults under source.<id>.<key>)

    func getPreference(_ key: String) -> String? {
        let udKey = "source.\(sourceId).\(key)"
        return UserDefaults.standard.string(forKey: udKey)
    }

    func setPreference(_ key: String, _ value: String) {
        let udKey = "source.\(sourceId).\(key)"
        UserDefaults.standard.set(value, forKey: udKey)
    }

    // MARK: - Credentials (persisted per-source)

    private var credentialUsernameKey: String { "source.\(sourceId).credential.username" }
    private var credentialPasswordKey: String { "source.\(sourceId).credential.password" }

    func getCredentialUsername() -> String? {
        UserDefaults.standard.string(forKey: credentialUsernameKey)
    }

    func getCredentialPassword() -> String? {
        UserDefaults.standard.string(forKey: credentialPasswordKey)
    }

    func setCredential(_ username: String, _ password: String) {
        UserDefaults.standard.set(username, forKey: credentialUsernameKey)
        UserDefaults.standard.set(password, forKey: credentialPasswordKey)
    }

    func clearCredential() {
        UserDefaults.standard.removeObject(forKey: credentialUsernameKey)
        UserDefaults.standard.removeObject(forKey: credentialPasswordKey)
    }

    func hasCredential() -> Bool {
        let username = UserDefaults.standard.string(forKey: credentialUsernameKey)
        return username != nil && !username!.isEmpty
    }

    // MARK: - Cookies (per-source, persisted)

    private let cookieManager = CookieManager.shared

    /// Get a specific cookie value by name for a URL.
    func getCookie(_ name: String, _ url: String) -> String? {
        guard let parsed = URL(string: url) else { return nil }
        return cookieManager.getSourceCookie(sourceId: sourceId, name: name, url: parsed)?.value
    }

    /// Get all cookies for a URL as a JS object { name: value, ... }.
    func getCookies(_ url: String) -> JSValue {
        guard let context else { return JSValue(undefinedIn: nil) }
        guard let parsed = URL(string: url) else { return JSValue(object: [String: String](), in: context) }
        let cookies = cookieManager.getSourceCookies(sourceId: sourceId, for: parsed)
        var dict: [String: String] = [:]
        for cookie in cookies {
            dict[cookie.name] = cookie.value
        }
        return JSValue(object: dict, in: context)
    }

    /// Set a cookie in the per-source jar. expirySeconds=0 means session cookie.
    func setCookie(_ name: String, _ value: String, _ domain: String, _ path: String, _ expirySeconds: Int) -> Bool {
        var props: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path.isEmpty ? "/" : path
        ]
        if expirySeconds > 0 {
            props[.expires] = Date().addingTimeInterval(TimeInterval(expirySeconds))
        }
        guard let cookie = HTTPCookie(properties: props) else { return false }
        cookieManager.setSourceCookie(sourceId: sourceId, cookie: cookie)
        return true
    }

    /// Delete a specific cookie by name and domain from the per-source jar.
    func deleteCookie(_ name: String, _ domain: String) {
        cookieManager.deleteSourceCookie(sourceId: sourceId, name: name, domain: domain)
    }

    /// Clear all cookies for this source.
    func clearCookies() {
        cookieManager.clearSourceCookies(sourceId: sourceId)
    }
}
