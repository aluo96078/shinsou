import Foundation
import JavaScriptCore
import SwiftSoup
import MihonSourceAPI

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

    // Preferences (per-source)
    func getPreference(_ key: String) -> String?
    func setPreference(_ key: String, _ value: String)

    // Legacy compatibility
    func parseHtml(_ html: String, _ selector: String) -> JSValue
}

/// Bridge object that provides native capabilities to JS plugins
@objc class JSBridge: NSObject, JSBridgeExports {
    weak var context: JSContext?
    private var preferences: [String: String] = [:]

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

    func httpGet(_ url: String) -> JSValue {
        return httpGetWithHeaders(url, JSValue(undefinedIn: context))
    }

    func httpGetWithHeaders(_ url: String, _ headers: JSValue) -> JSValue {
        guard let context else { return JSValue(undefinedIn: nil) }
        guard let requestUrl = URL(string: url) else {
            return JSValue(nullIn: context)
        }

        var request = URLRequest(url: requestUrl)
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let headerDict = headers.toDictionary() as? [String: String] {
            for (key, value) in headerDict {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?
        var resultError: Error?

        URLSession.shared.dataTask(with: request) { data, _, error in
            resultData = data
            resultError = error
            semaphore.signal()
        }.resume()
        semaphore.wait()

        if let data = resultData, let str = String(data: data, encoding: .utf8) {
            return JSValue(object: str, in: context)
        }
        if let error = resultError {
            return JSValue(object: ["error": error.localizedDescription], in: context)
        }
        return JSValue(nullIn: context)
    }

    func httpPost(_ url: String, _ body: String, _ headers: JSValue) -> JSValue {
        guard let context else { return JSValue(undefinedIn: nil) }
        guard let requestUrl = URL(string: url) else {
            return JSValue(nullIn: context)
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.httpBody = body.data(using: .utf8)

        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let headerDict = headers.toDictionary() as? [String: String] {
            for (key, value) in headerDict {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?

        URLSession.shared.dataTask(with: request) { data, _, _ in
            resultData = data
            semaphore.signal()
        }.resume()
        semaphore.wait()

        if let data = resultData, let str = String(data: data, encoding: .utf8) {
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

    // MARK: - Preferences

    func getPreference(_ key: String) -> String? {
        preferences[key]
    }

    func setPreference(_ key: String, _ value: String) {
        preferences[key] = value
    }
}
