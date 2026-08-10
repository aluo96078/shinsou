import SwiftUI
import ShinsouI18n
import WebKit
import ShinsouDomain
import ShinsouSourceAPI

/// A destination used by the manga detail page's WebView action.
struct MangaWebViewDestination: Identifiable {
    let url: URL
    let title: String

    var id: URL { url }
}

/// Resolves the URL stored by a manga into the absolute page URL used by a
/// source. Most sources already store an absolute URL, while HTTP/plugin
/// sources commonly store a path relative to their base URL.
@MainActor
enum MangaWebURLResolver {
    static func resolve(manga: Manga) -> URL? {
        guard !manga.url.isEmpty else { return nil }

        if let url = URL(string: manga.url), url.scheme != nil {
            return url
        }

        guard let catalogueSource = SourceManager.shared.getCatalogueSource(id: manga.source) else {
            return nil
        }

        let baseURLString: String?
        if let source = catalogueSource as? HttpSource {
            baseURLString = source.baseUrl
        } else if let source = catalogueSource as? JSSourceProxy {
            baseURLString = source.baseUrl
        } else if let source = catalogueSource as? StubCatalogueSource {
            baseURLString = source.baseUrl
        } else {
            baseURLString = nil
        }

        guard let baseURLString,
              let baseURL = URL(string: baseURLString) else {
            return nil
        }
        return URL(string: manga.url, relativeTo: baseURL)?.absoluteURL
    }
}

/// A regular manga page WebView. It deliberately keeps navigation enabled so
/// links and JavaScript redirects inside the source page can continue to work.
struct MangaWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        /// Sites often use target="_blank" for chapter links. WKWebView does
        /// not navigate those requests unless the UI delegate handles them.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let requestURL = navigationAction.request.url else { return nil }
            webView.load(URLRequest(url: requestURL))
            return nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Keep http(s) navigation inside this WebView. WKWebView cannot
            // render unsupported schemes, so cancel those requests here.
            if let scheme = navigationAction.request.url?.scheme?.lowercased(),
               scheme != "http", scheme != "https" {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

struct MangaWebViewScreen: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MangaWebView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(MR.strings.commonDone) { dismiss() }
                    }
                }
        }
    }
}

/// A WKWebView-based Cloudflare bypass screen.
///
/// Opens the target URL in a real browser engine so the user (or Cloudflare's JS challenge)
/// can solve the verification. Once the `cf_clearance` cookie appears, the cookies are synced
/// to `HTTPCookieStorage.shared` and the view dismisses automatically.
struct CloudflareWebView: UIViewRepresentable {
    let url: URL
    let onCookiesObtained: ([HTTPCookie]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: CloudflareWebView
        private var checkTimer: Timer?
        private var dismissed = false

        init(parent: CloudflareWebView) {
            self.parent = parent
        }

        deinit {
            checkTimer?.invalidate()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Start polling for cf_clearance cookie after each navigation
            startCookiePolling(webView: webView)
        }

        private func startCookiePolling(webView: WKWebView) {
            checkTimer?.invalidate()
            checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, weak webView] _ in
                guard let self, let webView, !self.dismissed else { return }
                self.checkCookies(webView: webView)
            }
        }

        private func checkCookies(webView: WKWebView) {
            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
            cookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.dismissed else { return }

                let hasClearance = cookies.contains { $0.name == "cf_clearance" }
                if hasClearance {
                    self.dismissed = true
                    self.checkTimer?.invalidate()

                    // Sync all cookies to HTTPCookieStorage
                    let storage = HTTPCookieStorage.shared
                    for cookie in cookies {
                        storage.setCookie(cookie)
                    }

                    DispatchQueue.main.async {
                        self.parent.onCookiesObtained(cookies)
                    }
                }
            }
        }
    }
}

/// SwiftUI wrapper that presents the Cloudflare bypass as a sheet.
struct CloudflareBypassSheet: View {
    let siteUrl: String
    let onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var status = "正在載入，請等待驗證完成..."
    @State private var succeeded = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status bar
                HStack {
                    if succeeded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(status)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))

                // WebView
                if let url = URL(string: siteUrl) {
                    CloudflareWebView(url: url) { cookies in
                        let cfCookie = cookies.first { $0.name == "cf_clearance" }
                        if cfCookie != nil {
                            status = "驗證成功！正在返回..."
                            succeeded = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                dismiss()
                                onSuccess()
                            }
                        }
                    }
                } else {
                    Text(MR.strings.cloudflareInvalidUrl(siteUrl))
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(MR.strings.cloudflareVerification)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(MR.strings.actionCancel) { dismiss() }
                }
            }
        }
    }
}
