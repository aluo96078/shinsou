import SwiftUI
import MihonSourceAPI
import MihonCore
import MihonI18n

// MARK: - ExtensionDetailScreen

/// Detail screen for an installed extension.
/// Shows metadata, per-source toggles, cookie clearing, and uninstall.
struct ExtensionDetailScreen: View {
    let `extension`: ExtensionModel

    @ObservedObject private var sourceManager = SourceManager.shared
    @ObservedObject private var extensionManager = ExtensionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showUninstallConfirm = false
    @State private var showClearCookiesConfirm: Int64? = nil
    @State private var uninstallError: String?
    @State private var showUninstallError = false
    @State private var isReinstalling = false
    @State private var reinstallError: String?
    @State private var showReinstallError = false

    // MARK: - Derived data

    /// All sources registered by this extension (match by lang + name prefix or exact name).
    private var extensionSources: [any CatalogueSource] {
        sourceManager.catalogueSources.filter { source in
            source.lang == `extension`.lang &&
            source.name.hasPrefix(`extension`.name)
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            headerSection
            sourcesSection
            actionsSection
            dangerSection
        }
        .navigationTitle(`extension`.name)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            MR.strings.browseUninstallConfirm,
            isPresented: $showUninstallConfirm,
            titleVisibility: .visible
        ) {
            Button(MR.strings.browseUninstall, role: .destructive) {
                uninstallExtension()
            }
            Button(MR.strings.commonCancel, role: .cancel) {}
        } message: {
            Text("This will remove all sources provided by this extension. Library entries will not be deleted.")
        }
        .confirmationDialog(
            MR.strings.browseClearCookies,
            isPresented: Binding(
                get: { showClearCookiesConfirm != nil },
                set: { if !$0 { showClearCookiesConfirm = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(MR.strings.browseClear, role: .destructive) {
                if let sourceId = showClearCookiesConfirm {
                    clearCookies(for: sourceId)
                }
                showClearCookiesConfirm = nil
            }
            Button(MR.strings.commonCancel, role: .cancel) { showClearCookiesConfirm = nil }
        } message: {
            Text(MR.strings.browseCookiesConfirm)
        }
        .alert(MR.strings.browseUninstallFailed, isPresented: $showUninstallError) {
            Button(MR.strings.commonOk, role: .cancel) {}
        } message: {
            Text(uninstallError ?? MR.strings.browseUnknownError)
        }
        .alert("刷新失敗", isPresented: $showReinstallError) {
            Button(MR.strings.commonOk, role: .cancel) {}
        } message: {
            Text(reinstallError ?? "未知錯誤")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 60, height: 60)
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(`extension`.name)
                        .font(.headline)

                    HStack(spacing: 6) {
                        Text(
                            Locale.current.localizedString(forLanguageCode: `extension`.lang)
                                ?? `extension`.lang.uppercased()
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        Text("v\(`extension`.displayVersion)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if `extension`.nsfw {
                            Text("18+")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var sourcesSection: some View {
        Section {
            if extensionSources.isEmpty {
                Text("No sources loaded for this extension.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(extensionSources, id: \.id) { source in
                    SourceToggleRow(
                        source: source,
                        onClearCookies: { showClearCookiesConfirm = source.id }
                    )
                }
            }
        } header: {
            Text("\(MR.strings.browseSources) (\(extensionSources.count))")
        } footer: {
            Text("Disabled sources will not appear in the browse tab.")
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                Task {
                    isReinstalling = true
                    do {
                        try await extensionManager.forceReinstallExtension(`extension`)
                    } catch {
                        reinstallError = error.localizedDescription
                        showReinstallError = true
                    }
                    isReinstalling = false
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("強制刷新套件")
                    Spacer()
                    if isReinstalling {
                        ProgressView()
                    }
                }
            }
            .disabled(isReinstalling)
        } header: {
            Text("操作")
        } footer: {
            Text("從倉庫重新下載並載入插件腳本，不檢查版號。")
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showUninstallConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(MR.strings.browseUninstall)
                }
            }
        } header: {
            Text("Danger Zone")
        }
    }

    // MARK: - Actions

    private func uninstallExtension() {
        extensionManager.uninstallExtension(`extension`)
        dismiss()
    }

    private func clearCookies(for sourceId: Int64) {
        // Clear cookies stored in HTTPCookieStorage for this source.
        // Sources that use WKWebView share the default cookie store; JS sources
        // using URLSession share HTTPCookieStorage.
        let storage = HTTPCookieStorage.shared
        if let cookies = storage.cookies {
            for cookie in cookies {
                storage.deleteCookie(cookie)
            }
        }
    }
}

// MARK: - SourceToggleRow

/// A row displaying a source with an enable/disable toggle and a cookie-clear action.
private struct SourceToggleRow: View {
    let source: any CatalogueSource
    let onClearCookies: () -> Void

    @AppStorage private var isEnabled: Bool

    init(source: any CatalogueSource, onClearCookies: @escaping () -> Void) {
        self.source = source
        self.onClearCookies = onClearCookies
        _isEnabled = AppStorage(
            wrappedValue: true,
            "source.\(source.id).enabled"
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .resizable()
                .scaledToFit()
                .padding(7)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.body)
                Text(source.lang.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                onClearCookies()
            } label: {
                Label(MR.strings.browseClearCookies, systemImage: "trash")
            }
            .tint(.orange)
        }
        .contextMenu {
            Button {
                onClearCookies()
            } label: {
                Label(MR.strings.browseClearCookies, systemImage: "hand.raised")
            }
        }
    }
}
