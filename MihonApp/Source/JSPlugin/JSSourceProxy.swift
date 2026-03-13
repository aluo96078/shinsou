import Foundation
import JavaScriptCore
import MihonSourceAPI

/// Proxy that wraps a JavaScript plugin to conform to CatalogueSource protocol.
///
/// The JS plugin can implement either:
/// 1. **Full mode** — define a `source` object with getPopularManga/getSearchManga/etc methods
///    that use `Jsoup.parse()` / `Element.select()` / etc (Jsoup-like DOM API).
/// 2. **ParsedHttpSource mode** — define selectors and let the runtime handle HTML fetching & parsing,
///    mirroring Android's `ParsedHttpSource` pattern.
final class JSSourceProxy: CatalogueSource {
    let id: Int64
    let name: String
    let lang: String
    let supportsLatest: Bool
    let baseUrl: String

    /// HTTP headers this source requires (User-Agent, Cookie, Referer, etc.)
    var sourceHeaders: [String: String] { bridge.defaultHeaders }

    /// Recent plugin log messages from the last JS call.
    var recentPluginLogs: [String] { bridge.pluginLogs }

    private let context: JSContext
    private let bridge: JSBridge

    init?(scriptContent: String, manifest: PluginManifest) {
        let ctx = JSContext()!
        self.context = ctx
        self.bridge = JSBridge(context: ctx)

        // Inject bridge
        ctx.setObject(bridge, forKeyedSubscript: "bridge" as NSString)

        // Inject console.log / console.error / console.warn
        let pluginName = manifest.name
        let bridgeRef = self.bridge
        let consoleLog: @convention(block) (String) -> Void = { msg in
            bridgeRef.log(msg)
        }
        ctx.setObject(consoleLog, forKeyedSubscript: "console_log" as NSString)
        ctx.evaluateScript("var console = { log: console_log, error: console_log, warn: console_log, info: console_log };")

        // Inject DOM library (Jsoup.parse, Element, Elements, SManga, SChapter, Page, etc.)
        ctx.evaluateScript(JSDomLib.script)

        // Handle JS exceptions
        ctx.exceptionHandler = { _, exception in
            if let ex = exception {
                print("[JS:\(pluginName)] Exception: \(ex)")
            }
        }

        // Load the plugin script
        ctx.evaluateScript(scriptContent)

        // Extract source properties
        guard let sourceObj = ctx.objectForKeyedSubscript("source"),
              !sourceObj.isUndefined else {
            return nil
        }

        // Base URL — from manifest or source object
        let jsBaseUrl = sourceObj.objectForKeyedSubscript("baseUrl")?.toString()
        let manifestBaseUrl = manifest.sources?.first?.baseUrl
        let resolvedBaseUrl = jsBaseUrl ?? manifestBaseUrl ?? ""
        self.baseUrl = resolvedBaseUrl

        // Inject baseUrl as a global so the script can reference it
        ctx.setObject(resolvedBaseUrl, forKeyedSubscript: "baseUrl" as NSString)

        // Source ID: prefer manifest source entry ID, fall back to hash
        if let entry = manifest.sources?.first {
            self.id = entry.id
        } else {
            self.id = Int64(manifest.id.hashValue)
        }
        self.name = manifest.name
        self.lang = manifest.lang
        self.supportsLatest = sourceObj.objectForKeyedSubscript("supportsLatest")?.toBool() ?? false

        // Apply custom headers if defined by the plugin
        if let headersObj = sourceObj.objectForKeyedSubscript("headers"),
           !headersObj.isUndefined,
           let headersDict = headersObj.toDictionary() as? [String: String] {
            for (key, value) in headersDict {
                bridge.defaultHeaders[key] = value
            }
        }

        // Set Referer to baseUrl by default if not already set
        if bridge.defaultHeaders["Referer"] == nil && !resolvedBaseUrl.isEmpty {
            bridge.defaultHeaders["Referer"] = resolvedBaseUrl
        }
    }

    // MARK: - Source Protocol

    func getMangaDetails(manga: SManga) async throws -> SManga {
        try await callJSFunction("getMangaDetails", args: [mangaToJSDict(manga)])
    }

    func getChapterList(manga: SManga) async throws -> [SChapter] {
        let result: [[String: Any]] = try await callJSArrayFunction("getChapterList", args: [mangaToJSDict(manga)])
        return result.map { dict in
            SChapter(
                url: dict["url"] as? String ?? "",
                name: dict["name"] as? String ?? "",
                scanlator: dict["scanlator"] as? String,
                dateUpload: dict["dateUpload"] as? Int64 ?? 0,
                chapterNumber: dict["chapterNumber"] as? Double ?? -1
            )
        }
    }

    func getPageList(chapter: SChapter) async throws -> [Page] {
        let result: [[String: Any]] = try await callJSArrayFunction("getPageList", args: [["url": chapter.url]])
        return result.enumerated().map { index, dict in
            Page(
                index: dict["index"] as? Int ?? index,
                url: dict["url"] as? String ?? "",
                imageUrl: dict["imageUrl"] as? String
            )
        }
    }

    // MARK: - CatalogueSource Protocol

    func getPopularManga(page: Int) async throws -> MangasPage {
        try await callMangasPageFunction("getPopularManga", page: page)
    }

    func getLatestUpdates(page: Int) async throws -> MangasPage {
        try await callMangasPageFunction("getLatestUpdates", page: page)
    }

    func getSearchManga(page: Int, query: String, filters: FilterList) async throws -> MangasPage {
        try await callMangasPageFunction("getSearchManga", page: page, query: query, filters: filters)
    }

    func getFilterList() -> FilterList {
        // Call JS getFilterList if available
        guard let sourceObj = context.objectForKeyedSubscript("source"),
              !sourceObj.isUndefined,
              let result = sourceObj.invokeMethod("getFilterList", withArguments: []),
              let array = result.toArray() as? [[String: Any]] else {
            return []
        }
        return JSSourceProxy.parseFilters(array)
    }

    // MARK: - Filter parsing

    static func parseFilters(_ array: [[String: Any]]) -> FilterList {
        var filters: [Filter] = []
        for dict in array {
            guard let type = dict["type"] as? String,
                  let name = dict["name"] as? String else { continue }
            switch type {
            case "header":
                filters.append(.header(name: name))
            case "separator":
                filters.append(.separator)
            case "select":
                let values = dict["values"] as? [String] ?? []
                let state = dict["state"] as? Int ?? 0
                filters.append(.select(name: name, values: values, state: state))
            case "text":
                let state = dict["state"] as? String ?? ""
                filters.append(.text(name: name, state: state))
            case "checkBox":
                let state = dict["state"] as? Bool ?? false
                filters.append(.checkBox(name: name, state: state))
            case "triState":
                let state = dict["state"] as? Int ?? 0
                let triState: Filter.TriStateValue
                switch state {
                case 1: triState = .include
                case 2: triState = .exclude
                default: triState = .ignore
                }
                filters.append(.triState(name: name, state: triState))
            case "sort":
                let values = dict["values"] as? [String] ?? []
                filters.append(.sort(name: name, values: values, selection: nil))
            default:
                break
            }
        }
        return FilterList(filters)
    }

    // MARK: - Filter serialization

    /// Convert FilterList to JS-compatible array of dictionaries.
    static func filtersToJS(_ filterList: FilterList) -> [[String: Any]] {
        return filterList.map { filter -> [String: Any] in
            switch filter {
            case .header(let name):
                return ["type": "header", "name": name]
            case .separator:
                return ["type": "separator", "name": ""]
            case .select(let name, let values, let state):
                return ["type": "select", "name": name, "values": values, "state": state]
            case .text(let name, let state):
                return ["type": "text", "name": name, "state": state]
            case .checkBox(let name, let state):
                return ["type": "checkBox", "name": name, "state": state]
            case .triState(let name, let state):
                let intState: Int
                switch state {
                case .ignore: intState = 0
                case .include: intState = 1
                case .exclude: intState = 2
                }
                return ["type": "triState", "name": name, "state": intState]
            case .group(let name, let filters):
                let subFilters = filtersToJS(filters)
                return ["type": "group", "name": name, "filters": subFilters]
            case .sort(let name, let values, let selection):
                var dict: [String: Any] = ["type": "sort", "name": name, "values": values]
                if let sel = selection {
                    dict["selection"] = ["index": sel.index, "ascending": sel.ascending]
                }
                return dict
            }
        }
    }

    // MARK: - JS Helpers

    private func callMangasPageFunction(_ name: String, page: Int, query: String? = nil, filters: FilterList? = nil) async throws -> MangasPage {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: JSPluginError.contextDeallocated)
                    return
                }

                // Release DOM handles from previous calls
                self.bridge.domReleaseAll()

                var args: [Any] = [page]
                if let query { args.append(query) }
                if let filters, !filters.isEmpty {
                    args.append(Self.filtersToJS(filters))
                }

                guard let sourceObj = self.context.objectForKeyedSubscript("source"),
                      !sourceObj.isUndefined else {
                    continuation.resume(returning: MangasPage(mangas: [], hasNextPage: false))
                    return
                }

                let result = sourceObj.invokeMethod(name, withArguments: args)

                // Check for JS exception
                if let exception = self.context.exception {
                    print("[JSSourceProxy] JS exception in \(name): \(exception)")
                    self.context.exception = nil
                    continuation.resume(returning: MangasPage(mangas: [], hasNextPage: false))
                    return
                }

                guard let dict = result?.toDictionary() else {
                    print("[JSSourceProxy] \(name) returned non-dict result: \(String(describing: result))")
                    continuation.resume(returning: MangasPage(mangas: [], hasNextPage: false))
                    return
                }

                let hasNextPage = dict["hasNextPage"] as? Bool ?? false
                let mangaArray = dict["mangas"] as? [[String: Any]] ?? []
                let mangas = mangaArray.map { self.dictToSManga($0) }
                print("[JSSourceProxy] \(name) returned \(mangas.count) mangas, hasNext=\(hasNextPage)")

                continuation.resume(returning: MangasPage(mangas: mangas, hasNextPage: hasNextPage))
            }
        }
    }

    private func callJSFunction<T>(_ name: String, args: [Any]) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: JSPluginError.contextDeallocated)
                    return
                }

                self.bridge.domReleaseAll()

                guard let sourceObj = self.context.objectForKeyedSubscript("source"),
                      !sourceObj.isUndefined else {
                    continuation.resume(throwing: JSPluginError.functionNotFound(name))
                    return
                }

                let result = sourceObj.invokeMethod(name, withArguments: args)

                if let dict = result?.toDictionary() as? [String: Any] {
                    let manga = self.dictToSManga(dict)
                    if let manga = manga as? T {
                        continuation.resume(returning: manga)
                        return
                    }
                }

                continuation.resume(throwing: JSPluginError.invalidResult)
            }
        }
    }

    private func callJSArrayFunction(_ name: String, args: [Any]) async throws -> [[String: Any]] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: JSPluginError.contextDeallocated)
                    return
                }

                self.bridge.clearPluginLogs()
                self.bridge.domReleaseAll()

                guard let sourceObj = self.context.objectForKeyedSubscript("source"),
                      !sourceObj.isUndefined else {
                    continuation.resume(throwing: JSPluginError.functionNotFound(name))
                    return
                }

                let result = sourceObj.invokeMethod(name, withArguments: args)
                let array = result?.toArray()?.compactMap { $0 as? [String: Any] } ?? []
                continuation.resume(returning: array)
            }
        }
    }

    private func dictToSManga(_ dict: [String: Any]) -> SManga {
        var manga = SManga(url: dict["url"] as? String ?? "")
        manga.title = dict["title"] as? String ?? ""
        manga.author = dict["author"] as? String
        manga.artist = dict["artist"] as? String
        manga.description = dict["description"] as? String
        manga.genre = dict["genre"] as? [String]
        manga.thumbnailUrl = dict["thumbnailUrl"] as? String ?? dict["thumbnail_url"] as? String
        if let statusInt = dict["status"] as? Int {
            manga.status = MangaStatus(rawValue: statusInt) ?? .unknown
        }
        manga.initialized = dict["initialized"] as? Bool ?? false
        return manga
    }

    private func mangaToJSDict(_ manga: SManga) -> [String: Any] {
        var dict: [String: Any] = ["url": manga.url, "title": manga.title]
        if let author = manga.author { dict["author"] = author }
        if let artist = manga.artist { dict["artist"] = artist }
        if let desc = manga.description { dict["description"] = desc }
        if let genres = manga.genre { dict["genre"] = genres }
        if let thumb = manga.thumbnailUrl { dict["thumbnailUrl"] = thumb }
        dict["status"] = manga.status.rawValue
        return dict
    }
}

enum JSPluginError: Error, LocalizedError {
    case contextDeallocated
    case functionNotFound(String)
    case invalidResult
    case scriptLoadFailed
    case signatureInvalid

    var errorDescription: String? {
        switch self {
        case .contextDeallocated: return "JS context was deallocated"
        case .functionNotFound(let name): return "JS function '\(name)' not found"
        case .invalidResult: return "Invalid result from JS function"
        case .scriptLoadFailed: return "Failed to load JS script"
        case .signatureInvalid: return "Plugin signature verification failed"
        }
    }
}
