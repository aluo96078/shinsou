import SwiftUI
import MihonI18n

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

    @State private var showClearCacheConfirmation    = false
    @State private var showClearDatabaseConfirmation = false
    @State private var showResetSettingsConfirmation = false
    @State private var showDumpLogsSuccess           = false
    @State private var cacheCleared                  = false
    @State private var dbCleared                     = false
    @State private var settingsReset                 = false

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
}

#Preview {
    NavigationStack {
        SettingsAdvancedScreen()
    }
}
