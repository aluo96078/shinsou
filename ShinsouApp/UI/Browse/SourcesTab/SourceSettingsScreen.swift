import SwiftUI
import UniformTypeIdentifiers
import ShinsouSourceAPI
import ShinsouI18n

// MARK: - SourceSettingsScreen

/// Unified settings screen for any source — network overrides, login, and plugin preferences.
/// Accessible for ALL CatalogueSource instances, not just ConfigurableSource.
struct SourceSettingsScreen: View {
    let source: any CatalogueSource

    var body: some View {
        List {
            // MARK: Network overrides (DoH / Proxy)
            networkSection

            // MARK: Credentials (for all JSSourceProxy)
            if let jsProxy = source as? JSSourceProxy {
                CredentialSection(proxy: jsProxy)
            }

            // MARK: Cookies (for all JSSourceProxy)
            if source is JSSourceProxy {
                CookieSection(sourceId: source.id, baseUrl: (source as? JSSourceProxy)?.baseUrl ?? "")
            }

            // MARK: Plugin preferences (only for ConfigurableSource)
            if let configurable = source as? any ConfigurableSource {
                preferencesSection(configurable)
            }
        }
        .navigationTitle(source.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Network Section

    @ViewBuilder
    private var networkSection: some View {
        Section {
            NetworkOverridePicker(
                title: MR.strings.sourceSettingsDoh,
                sourceId: source.id,
                networkKey: "doh"
            )
            NetworkOverridePicker(
                title: MR.strings.sourceSettingsProxy,
                sourceId: source.id,
                networkKey: "proxy"
            )
        } header: {
            Text(MR.strings.sourceSettingsNetwork)
        } footer: {
            Text(MR.strings.sourceSettingsNetworkFooter)
        }
    }

    // MARK: - Preferences Section

    @ViewBuilder
    private func preferencesSection(_ configurable: any ConfigurableSource) -> some View {
        let prefs = configurable.getPreferenceDefinitions()
        if !prefs.isEmpty {
            Section(MR.strings.sourceSettingsPreferences) {
                ForEach(Array(prefs.enumerated()), id: \.offset) { _, pref in
                    preferenceRow(for: pref, sourceId: configurable.id)
                }
            }
        }
    }

    @ViewBuilder
    private func preferenceRow(for preference: SourcePreference, sourceId: Int64) -> some View {
        switch preference {
        case let .toggle(key, title, summary, defaultValue):
            TogglePrefRow(
                storageKey: "source.\(sourceId).\(key)",
                title: title,
                summary: summary,
                defaultValue: defaultValue
            )

        case let .textField(key, title, summary, defaultValue):
            TextFieldPrefRow(
                storageKey: "source.\(sourceId).\(key)",
                title: title,
                summary: summary,
                defaultValue: defaultValue
            )

        case let .select(key, title, entries, entryValues, defaultValue):
            SelectPrefRow(
                storageKey: "source.\(sourceId).\(key)",
                title: title,
                entries: entries,
                entryValues: entryValues,
                defaultValue: defaultValue
            )

        case let .multiSelect(key, title, entries, entryValues, defaultValues):
            MultiSelectPrefRow(
                storageKey: "source.\(sourceId).\(key)",
                title: title,
                entries: entries,
                entryValues: entryValues,
                defaultValues: defaultValues
            )
        }
    }
}

// MARK: - Network Override Picker

/// 3-state picker: Follow Global / Force On / Force Off
private struct NetworkOverridePicker: View {
    let title: String
    let sourceId: Int64
    let networkKey: String

    @State private var selection: String

    private var storageKey: String { "source.\(sourceId).network.\(networkKey)" }

    init(title: String, sourceId: Int64, networkKey: String) {
        self.title = title
        self.sourceId = sourceId
        self.networkKey = networkKey
        let stored = UserDefaults.standard.string(forKey: "source.\(sourceId).network.\(networkKey)") ?? "global"
        _selection = State(initialValue: stored)
    }

    var body: some View {
        Picker(title, selection: $selection) {
            Text(MR.strings.sourceSettingsFollowGlobal).tag("global")
            Text(MR.strings.sourceSettingsForceOn).tag("on")
            Text(MR.strings.sourceSettingsForceOff).tag("off")
        }
        .onChange(of: selection) { newValue in
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }
}

// MARK: - Credential Section

private struct CredentialSection: View {
    let proxy: JSSourceProxy
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var hasSaved: Bool = false
    @State private var isLoggingIn: Bool = false
    @State private var loginFailed: Bool = false

    private var usernameKey: String { "source.\(proxy.id).credential.username" }
    private var passwordKey: String { "source.\(proxy.id).credential.password" }

    var body: some View {
        Section {
            TextField(MR.strings.sourceSettingsUsername, text: $username)
                .textContentType(.username)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            SecureField(MR.strings.sourceSettingsPassword, text: $password)
                .textContentType(.password)

            if proxy.supportsLogin {
                // Plugin supports login — show login button that calls JS login()
                Button {
                    performLogin()
                } label: {
                    HStack {
                        Text(MR.strings.sourceSettingsLoginButton)
                        Spacer()
                        if isLoggingIn {
                            ProgressView().controlSize(.small)
                        } else if hasSaved {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                }
                .disabled(username.isEmpty || password.isEmpty || isLoggingIn)

                if loginFailed {
                    Text(MR.strings.sourceSettingsLoginFailed)
                        .font(.caption).foregroundStyle(.red)
                }
            } else {
                // No login function — just save credentials
                Button {
                    UserDefaults.standard.set(username, forKey: usernameKey)
                    UserDefaults.standard.set(password, forKey: passwordKey)
                    hasSaved = true
                } label: {
                    HStack {
                        Text(MR.strings.sourceSettingsSaveCredential)
                        Spacer()
                        if hasSaved {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                }
                .disabled(username.isEmpty || password.isEmpty)
            }

            if hasSaved || !username.isEmpty {
                Button(role: .destructive) {
                    if proxy.supportsLogin { proxy.logout() }
                    UserDefaults.standard.removeObject(forKey: usernameKey)
                    UserDefaults.standard.removeObject(forKey: passwordKey)
                    username = ""
                    password = ""
                    hasSaved = false
                } label: {
                    Label(MR.strings.sourceSettingsLogout, systemImage: "trash")
                }
            }
        } header: {
            Text(MR.strings.sourceSettingsCredentials)
        } footer: {
            Text(MR.strings.sourceSettingsCredentialsFooter)
        }
        .onAppear {
            username = UserDefaults.standard.string(forKey: usernameKey) ?? ""
            password = UserDefaults.standard.string(forKey: passwordKey) ?? ""
            hasSaved = !username.isEmpty
        }
    }

    private func performLogin() {
        isLoggingIn = true
        loginFailed = false
        Task {
            do {
                let success = try await proxy.login(username: username, password: password)
                await MainActor.run {
                    isLoggingIn = false
                    if success {
                        hasSaved = true
                        loginFailed = false
                    } else {
                        loginFailed = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoggingIn = false
                    loginFailed = true
                }
            }
        }
    }
}

// MARK: - Cookie Section

private struct CookieSection: View {
    let sourceId: Int64
    let baseUrl: String
    @State private var cookies: [(name: String, value: String, domain: String)] = []
    @State private var showAddSheet: Bool = false
    @State private var showFileImporter: Bool = false
    @State private var importMessage: String?

    private let cookieManager = CookieManager.shared

    var body: some View {
        Section {
            if cookies.isEmpty {
                Text(MR.strings.sourceSettingsCookiesEmpty)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(cookies.enumerated()), id: \.offset) { index, cookie in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cookie.name).font(.body)
                        Text(cookie.value)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(cookie.domain)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            cookieManager.deleteSourceCookie(sourceId: sourceId, name: cookie.name, domain: cookie.domain)
                            reloadCookies()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Button {
                showAddSheet = true
            } label: {
                Label(MR.strings.sourceSettingsAddCookie, systemImage: "plus.circle")
            }

            Button {
                showFileImporter = true
            } label: {
                Label(MR.strings.sourceSettingsImportCookies, systemImage: "square.and.arrow.down")
            }

            if let importMessage {
                Text(importMessage)
                    .font(.caption)
                    .foregroundStyle(importMessage.contains("❌") ? .red : .green)
            }

            if !cookies.isEmpty {
                Button(role: .destructive) {
                    cookieManager.clearSourceCookies(sourceId: sourceId)
                    reloadCookies()
                } label: {
                    Label(MR.strings.sourceSettingsClearAllCookies, systemImage: "trash")
                }
            }
        } header: {
            Text(MR.strings.sourceSettingsCookies)
        } footer: {
            Text(MR.strings.sourceSettingsCookiesFooter)
        }
        .onAppear { reloadCookies() }
        .sheet(isPresented: $showAddSheet) {
            AddCookieSheet(sourceId: sourceId, defaultDomain: domainFromBaseUrl()) {
                reloadCookies()
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json, .plainText, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private func reloadCookies() {
        let all = cookieManager.getAllSourceCookies(sourceId: sourceId)
        cookies = all.map { (name: $0.name, value: $0.value, domain: $0.domain) }
    }

    private func domainFromBaseUrl() -> String {
        if let url = URL(string: baseUrl), let host = url.host {
            return host.hasPrefix(".") ? host : ".\(host)"
        }
        return ""
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let fileUrl = urls.first else {
            importMessage = "❌ " + MR.strings.sourceSettingsImportCookiesFailed
            return
        }

        guard fileUrl.startAccessingSecurityScopedResource() else {
            importMessage = "❌ " + MR.strings.sourceSettingsImportCookiesFailed
            return
        }
        defer { fileUrl.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: fileUrl),
              let content = String(data: data, encoding: .utf8) else {
            importMessage = "❌ " + MR.strings.sourceSettingsImportCookiesFailed
            return
        }

        let imported = CookieFileParser.parse(content: content)
        if imported.isEmpty {
            importMessage = "❌ " + MR.strings.sourceSettingsImportCookiesFailed
            return
        }

        for cookie in imported {
            cookieManager.setSourceCookie(sourceId: sourceId, cookie: cookie)
        }
        reloadCookies()
        importMessage = String(format: MR.strings.sourceSettingsImportCookiesSuccess, imported.count)
    }
}

// MARK: - Add Cookie Sheet

private struct AddCookieSheet: View {
    let sourceId: Int64
    let defaultDomain: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var value: String = ""
    @State private var domain: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField(MR.strings.sourceSettingsCookieName, text: $name)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField(MR.strings.sourceSettingsCookieValue, text: $value)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField(MR.strings.sourceSettingsCookieDomain, text: $domain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .navigationTitle(MR.strings.sourceSettingsAddCookie)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(MR.strings.sourceSettingsSaveCredential) {
                        saveCookie()
                    }
                    .disabled(name.isEmpty || value.isEmpty || domain.isEmpty)
                }
            }
            .onAppear {
                domain = defaultDomain
            }
        }
        .presentationDetents([.medium])
    }

    private func saveCookie() {
        var props: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: "/"
        ]
        // Long-lived cookie: 1 year
        props[.expires] = Date().addingTimeInterval(365 * 24 * 3600)
        if let cookie = HTTPCookie(properties: props) {
            CookieManager.shared.setSourceCookie(sourceId: sourceId, cookie: cookie)
        }
        onSave()
        dismiss()
    }
}

// MARK: - Cookie File Parser

/// Parses cookie files exported by browser extensions.
/// Supports:
/// 1. **Netscape/Mozilla cookies.txt** — tab-separated, used by "Get cookies.txt", "cookies.txt" extensions
/// 2. **JSON** — array of cookie objects, used by "EditThisCookie", "Cookie-Editor" extensions
private enum CookieFileParser {
    static func parse(content: String) -> [HTTPCookie] {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try JSON first (starts with [ or {)
        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            return parseJSON(trimmed)
        }

        // Otherwise try Netscape cookies.txt format
        return parseNetscape(trimmed)
    }

    // MARK: Netscape cookies.txt
    // Format: domain\tflag\tpath\tsecure\texpiration\tname\tvalue
    private static func parseNetscape(_ content: String) -> [HTTPCookie] {
        var cookies: [HTTPCookie] = []
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            let fields = trimmed.components(separatedBy: "\t")
            guard fields.count >= 7 else { continue }

            let domain = fields[0]
            // fields[1] = flag (subdomain matching)
            let path = fields[2]
            let secure = fields[3].uppercased() == "TRUE"
            let expiration = Double(fields[4]) ?? 0
            let name = fields[5]
            let value = fields[6]

            var props: [HTTPCookiePropertyKey: Any] = [
                .name: name,
                .value: value,
                .domain: domain,
                .path: path
            ]
            if secure {
                props[.secure] = "TRUE"
            }
            if expiration > 0 {
                props[.expires] = Date(timeIntervalSince1970: expiration)
            }
            if let cookie = HTTPCookie(properties: props) {
                cookies.append(cookie)
            }
        }
        return cookies
    }

    // MARK: JSON format
    // Supports: EditThisCookie, Cookie-Editor, and generic formats
    // Each object may have: name, value, domain, path, secure, httpOnly, expirationDate/expires/expiry
    private static func parseJSON(_ content: String) -> [HTTPCookie] {
        guard let data = content.data(using: .utf8) else { return [] }

        // Normalize: if top-level is a dict with a "cookies" key, unwrap it
        var array: [[String: Any]] = []
        if let parsed = try? JSONSerialization.jsonObject(with: data) {
            if let arr = parsed as? [[String: Any]] {
                array = arr
            } else if let dict = parsed as? [String: Any],
                      let nested = dict["cookies"] as? [[String: Any]] {
                array = nested
            }
        }

        guard !array.isEmpty else { return [] }

        var cookies: [HTTPCookie] = []
        for dict in array {
            guard let name = dict["name"] as? String,
                  let value = dict["value"] as? String else { continue }

            let domain = dict["domain"] as? String ?? ""
            let path = dict["path"] as? String ?? "/"
            let secure = dict["secure"] as? Bool ?? false
            let httpOnly = dict["httpOnly"] as? Bool ?? false

            var props: [HTTPCookiePropertyKey: Any] = [
                .name: name,
                .value: value,
                .domain: domain,
                .path: path
            ]
            if secure {
                props[.secure] = "TRUE"
            }
            if httpOnly {
                props[HTTPCookiePropertyKey("HttpOnly")] = "TRUE"
            }

            // Expiration: try multiple common key names
            let expiryValue = dict["expirationDate"] ?? dict["expires"] ?? dict["expiry"]
            if let ts = expiryValue as? Double, ts > 0 {
                props[.expires] = Date(timeIntervalSince1970: ts)
            } else if let ts = expiryValue as? Int, ts > 0 {
                props[.expires] = Date(timeIntervalSince1970: Double(ts))
            } else if let str = expiryValue as? String, let ts = Double(str), ts > 0 {
                props[.expires] = Date(timeIntervalSince1970: ts)
            }

            if let cookie = HTTPCookie(properties: props) {
                cookies.append(cookie)
            }
        }
        return cookies
    }
}

// MARK: - Inline preference row components (duplicated from SourcePreferencesScreen to avoid access issues)

private struct TogglePrefRow: View {
    let storageKey: String
    let title: String
    let summary: String
    let defaultValue: Bool

    @State private var value: Bool

    init(storageKey: String, title: String, summary: String, defaultValue: Bool) {
        self.storageKey = storageKey
        self.title = title
        self.summary = summary
        self.defaultValue = defaultValue
        _value = State(initialValue: UserDefaults.standard.object(forKey: storageKey) as? Bool ?? defaultValue)
    }

    var body: some View {
        Toggle(isOn: $value) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if !summary.isEmpty {
                    Text(summary).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: value) { newValue in
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }
}

private struct TextFieldPrefRow: View {
    let storageKey: String
    let title: String
    let summary: String
    let defaultValue: String

    @State private var value: String

    init(storageKey: String, title: String, summary: String, defaultValue: String) {
        self.storageKey = storageKey
        self.title = title
        self.summary = summary
        self.defaultValue = defaultValue
        _value = State(initialValue: UserDefaults.standard.string(forKey: storageKey) ?? defaultValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
            if !summary.isEmpty {
                Text(summary).font(.caption).foregroundStyle(.secondary)
            }
            TextField(defaultValue, text: $value)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: value) { newValue in
                    UserDefaults.standard.set(newValue, forKey: storageKey)
                }
        }
        .padding(.vertical, 4)
    }
}

private struct SelectPrefRow: View {
    let storageKey: String
    let title: String
    let entries: [String]
    let entryValues: [String]
    let defaultValue: String

    @State private var selectedValue: String

    init(storageKey: String, title: String, entries: [String], entryValues: [String], defaultValue: String) {
        self.storageKey = storageKey
        self.title = title
        self.entries = entries
        self.entryValues = entryValues
        self.defaultValue = defaultValue
        _selectedValue = State(initialValue: UserDefaults.standard.string(forKey: storageKey) ?? defaultValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Picker(title, selection: $selectedValue) {
                ForEach(Array(zip(entries, entryValues)), id: \.1) { label, value in
                    Text(label).tag(value)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(.vertical, 2)
        .onChange(of: selectedValue) { newValue in
            UserDefaults.standard.set(newValue, forKey: storageKey)
        }
    }
}

private struct MultiSelectPrefRow: View {
    let storageKey: String
    let title: String
    let entries: [String]
    let entryValues: [String]
    let defaultValues: Set<String>

    @State private var selectedValues: Set<String>

    init(storageKey: String, title: String, entries: [String], entryValues: [String], defaultValues: Set<String>) {
        self.storageKey = storageKey
        self.title = title
        self.entries = entries
        self.entryValues = entryValues
        self.defaultValues = defaultValues
        let stored = UserDefaults.standard.array(forKey: storageKey) as? [String]
        _selectedValues = State(initialValue: stored.map(Set.init) ?? defaultValues)
    }

    var body: some View {
        NavigationLink {
            List {
                ForEach(Array(zip(entries, entryValues)), id: \.1) { label, value in
                    Button {
                        if selectedValues.contains(value) {
                            selectedValues.remove(value)
                        } else {
                            selectedValues.insert(value)
                        }
                    } label: {
                        HStack {
                            Text(label).foregroundStyle(.primary)
                            Spacer()
                            if selectedValues.contains(value) {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedValues) { newValues in
                UserDefaults.standard.set(Array(newValues), forKey: storageKey)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                let selected = entryValues.enumerated()
                    .filter { selectedValues.contains($0.element) }
                    .map { entries[$0.offset] }
                Text(selected.isEmpty ? "None selected" : selected.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}
