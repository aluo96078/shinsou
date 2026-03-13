import SwiftUI
import WebKit

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
                    Text("Invalid URL: \(siteUrl)")
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Cloudflare 驗證")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
