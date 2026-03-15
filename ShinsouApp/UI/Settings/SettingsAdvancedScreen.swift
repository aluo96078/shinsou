import SwiftUI
import ShinsouI18n

// MARK: - Supporting types

private struct AppVersionInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
    static var display: String { "\(version) (\(build))" }
}

// MARK: - View

struct SettingsAdvancedScreen: View {

    @AppStorage(SettingsKeys.dnsOverHTTPS) private var dnsOverHTTPS: Bool = false
    @AppStorage(SettingsKeys.proxyEnabled) private var proxyEnabled: Bool = false
    @AppStorage(SettingsKeys.proxyWorkerUrl) private var proxyWorkerUrl: String = ""
    @AppStorage(SettingsKeys.proxyApiKey) private var proxyApiKey: String = ""

    @State private var showClearCacheConfirmation    = false
    @State private var showClearDatabaseConfirmation = false
    @State private var showResetSettingsConfirmation = false
    @State private var showDumpLogsSuccess           = false
    @State private var cacheCleared                  = false
    @State private var dbCleared                     = false
    @State private var settingsReset                 = false
    @State private var proxyTestState: ProxyTestState = .idle

    private enum ProxyTestState {
        case idle, testing, success, failed
    }

    var body: some View {
        List {
            // MARK: Cache
            Section {
                Button {
                    showClearCacheConfirmation = true
                } label: {
                    HStack {
                        Label(MR.strings.advancedClearImageCache, systemImage: "photo.on.rectangle.angled")
                        Spacer()
                        if cacheCleared {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .foregroundStyle(.primary)
            } header: {
                Text(MR.strings.advancedStorage)
            } footer: {
                Text(MR.strings.advancedClearImageCacheFooter)
            }

            // MARK: Database
            Section {
                Button(role: .destructive) {
                    showClearDatabaseConfirmation = true
                } label: {
                    HStack {
                        Label(MR.strings.advancedClearDatabase, systemImage: "cylinder.split.1x2")
                        Spacer()
                        if dbCleared {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                    }
                }
            } footer: {
                Text(MR.strings.advancedClearDatabaseFooter)
            }

            // MARK: Settings
            Section {
                Button(role: .destructive) {
                    showResetSettingsConfirmation = true
                } label: {
                    HStack {
                        Label(MR.strings.advancedResetSettings, systemImage: "arrow.counterclockwise")
                        Spacer()
                        if settingsReset {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                    }
                }
            } footer: {
                Text(MR.strings.advancedResetSettingsFooter)
            }

            // MARK: Network
            Section {
                Toggle(isOn: $dnsOverHTTPS) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.advancedDoh)
                        Text(MR.strings.advancedDohDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(MR.strings.advancedNetwork)
            } footer: {
                Text(MR.strings.advancedDohFooter)
            }

            // MARK: Proxy (Cloudflare Workers)
            Section {
                Toggle(isOn: $proxyEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.advancedProxyTitle)
                        Text(MR.strings.advancedProxyDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if proxyEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(MR.strings.advancedProxyWorkerUrl)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(MR.strings.advancedProxyUrlPlaceholder, text: $proxyWorkerUrl)
                            .textFieldStyle(.roundedBorder)
                            .font(.callout)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(MR.strings.advancedProxyApiKey)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SecureField(MR.strings.advancedProxyKeyPlaceholder, text: $proxyApiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.callout)
                    }

                    Button {
                        testProxy()
                    } label: {
                        HStack {
                            Label(MR.strings.advancedProxyTest, systemImage: "network")
                            Spacer()
                            if proxyTestState == .testing {
                                ProgressView()
                                    .controlSize(.small)
                            } else if proxyTestState == .success {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else if proxyTestState == .failed {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } header: {
                Text(MR.strings.advancedProxySection)
            } footer: {
                if proxyEnabled {
                    Text(MR.strings.advancedProxyFooter)
                }
            }

            // MARK: Diagnostics
            Section {
                Button {
                    dumpCrashLogs()
                } label: {
                    HStack {
                        Label(MR.strings.advancedCrashLogs, systemImage: "ladybug")
                        Spacer()
                        if showDumpLogsSuccess {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .foregroundStyle(.primary)
            } header: {
                Text(MR.strings.advancedDiagnostics)
            } footer: {
                Text(MR.strings.advancedCrashLogsFooter)
            }

            // MARK: About
            Section {
                HStack {
                    Text(MR.strings.advancedAppVersion)
                    Spacer()
                    Text(AppVersionInfo.display)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = AppVersionInfo.display
                    } label: {
                        Label(MR.strings.advancedCopyVersion, systemImage: "doc.on.doc")
                    }
                }
            } header: {
                Text(MR.strings.advancedAbout)
            }
        }
        .navigationTitle(MR.strings.advancedTitle)
        .navigationBarTitleDisplayMode(.inline)

        // MARK: - Confirmation dialogs

        .confirmationDialog(
            MR.strings.advancedClearCacheConfirm,
            isPresented: $showClearCacheConfirmation,
            titleVisibility: .visible
        ) {
            Button(MR.strings.advancedClearCacheButton, role: .destructive) { clearImageCache() }
            Button(MR.strings.commonCancel, role: .cancel) {}
        } message: {
            Text(MR.strings.advancedClearCacheMsg)
        }

        .confirmationDialog(
            MR.strings.advancedClearDbConfirm,
            isPresented: $showClearDatabaseConfirmation,
            titleVisibility: .visible
        ) {
            Button(MR.strings.advancedClearDatabase, role: .destructive) { clearDatabase() }
            Button(MR.strings.commonCancel, role: .cancel) {}
        } message: {
            Text(MR.strings.advancedClearDbMsg)
        }

        .confirmationDialog(
            MR.strings.advancedResetSettings,
            isPresented: $showResetSettingsConfirmation,
            titleVisibility: .visible
        ) {
            Button(MR.strings.advancedResetSettings, role: .destructive) { resetSettings() }
            Button(MR.strings.commonCancel, role: .cancel) {}
        } message: {
            Text(MR.strings.advancedResetSettingsFooter)
        }
    }

    // MARK: - Actions

    private func clearImageCache() {
        // Clear URLCache which holds cached HTTP responses / images
        URLCache.shared.removeAllCachedResponses()
        // Clear the Kingfisher / custom disk image cache directory if present
        let cacheURL = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first
        if let url = cacheURL {
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil
            )) ?? []
            contents.forEach { try? FileManager.default.removeItem(at: $0) }
        }
        cacheCleared = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { cacheCleared = false }
    }

    private func clearDatabase() {
        // TODO: wire up to the actual CoreData / SQLite store clearing logic
        dbCleared = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { dbCleared = false }
    }

    private func resetSettings() {
        let domain = Bundle.main.bundleIdentifier ?? ""
        UserDefaults.standard.removePersistentDomain(forName: domain)
        settingsReset = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { settingsReset = false }
    }

    private func dumpCrashLogs() {
        // TODO: Collect and export MetricKit / crash payloads via UIActivityViewController
        showDumpLogsSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showDumpLogsSuccess = false }
    }

    private func testProxy() {
        guard !proxyWorkerUrl.isEmpty else { return }
        proxyTestState = .testing

        let workerBase = proxyWorkerUrl.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let testTarget = "https://httpbin.org/get"
        guard let encoded = testTarget.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(workerBase)/?url=\(encoded)") else {
            proxyTestState = .failed
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        if !proxyApiKey.isEmpty {
            request.setValue(proxyApiKey, forHTTPHeaderField: "X-Proxy-Key")
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200, data != nil {
                    proxyTestState = .success
                } else {
                    proxyTestState = .failed
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    proxyTestState = .idle
                }
            }
        }.resume()
    }
}

#Preview {
    NavigationStack {
        SettingsAdvancedScreen()
    }
}
