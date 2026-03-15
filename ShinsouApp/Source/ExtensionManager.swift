import Foundation
import ShinsouSourceAPI
import ShinsouDomain
import ShinsouCore

// MARK: - Extension model used throughout UI

/// Unified extension model that merges info from repo index + local installation state.
struct ExtensionModel: Identifiable, Equatable, Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id: String  // pkg
    let name: String
    let pkg: String
    let version: String
    let versionCode: Int
    let lang: String
    let nsfw: Bool
    let sources: [SourceIndexEntry]
    let repoBaseUrl: String?
    let scriptUrl: String?      // relative path to .js file in repo
    let iconUrl: URL?           // custom icon URL
    let state: State

    enum State: Equatable {
        case available
        case installed
        case hasUpdate(newVersion: String)
        case installing
    }

    var displayVersion: String {
        switch state {
        case .hasUpdate(let newVer):
            return "\(version) → \(newVer)"
        default:
            return version
        }
    }

    /// 顯示名稱：優先使用 sources 中的 name（多個以「、」分隔），否則使用頂層 name。
    var displayName: String {
        let sourceNames = sources.map(\.name)
        if sourceNames.isEmpty {
            return name
        }
        return sourceNames.joined(separator: "、")
    }
}

// MARK: - ExtensionManager

/// Manages the life-cycle of JS extensions: list, install, update, uninstall.
/// Bridges `ExtensionRepoService` (remote index) with `PluginLoader` (local disk).
@MainActor
final class ExtensionManager: ObservableObject {

    static let shared = ExtensionManager()

    @Published private(set) var extensions: [ExtensionModel] = []
    @Published private(set) var isRefreshing = false

    private let repoService = ExtensionRepoService()
    private let pluginLoader = PluginLoader.shared
    private let sourceManager = SourceManager.shared

    private init() {
        // Clean up legacy bundled plugins before loading
        PluginLoader.shared.cleanupLegacyBundledPlugins()

        // Eagerly load installed extensions from disk so they appear immediately
        loadInstalledFromDisk()
    }

    /// Load installed extension manifests from disk and populate the extensions list.
    private func loadInstalledFromDisk() {
        let manifests = loadInstalledManifests()
        var result: [ExtensionModel] = []
        for manifest in manifests {
            let sources = manifest.sources ?? []
            result.append(ExtensionModel(
                id: manifest.id,
                name: manifest.name,
                pkg: manifest.id,
                version: manifest.version,
                versionCode: manifest.versionCode ?? versionInt(from: manifest.version),
                lang: manifest.lang,
                nsfw: manifest.nsfw,
                sources: sources,
                repoBaseUrl: nil,
                scriptUrl: nil,
                iconUrl: faviconUrl(from: sources),
                state: .installed
            ))
        }
        if !result.isEmpty {
            extensions = result
        }
    }

    // MARK: - Refresh all repos

    /// Fetch plugin index from every saved repo, merge with locally installed plugins,
    /// and produce a unified `[ExtensionModel]` list.
    func refreshAllRepos(repos: [ExtensionRepo]) async {
        isRefreshing = true
        defer { isRefreshing = false }

        let installedManifests = loadInstalledManifests()
        var result: [ExtensionModel] = []

        // Add installed-only extensions first (local plugins not in any repo)
        for manifest in installedManifests {
            let sources = manifest.sources ?? []
            result.append(ExtensionModel(
                id: manifest.id,
                name: manifest.name,
                pkg: manifest.id,
                version: manifest.version,
                versionCode: manifest.versionCode ?? versionInt(from: manifest.version),
                lang: manifest.lang,
                nsfw: manifest.nsfw,
                sources: sources,
                repoBaseUrl: nil,
                scriptUrl: nil,
                iconUrl: faviconUrl(from: sources),
                state: .installed
            ))
        }

        // Fetch remote indices
        for repo in repos {
            // Try new format (index.json with JS plugins) first
            if let pluginEntries = try? await repoService.fetchPluginIndex(baseUrl: repo.baseUrl) {
                for entry in pluginEntries {
                    let iconUrl = entry.iconUrl.flatMap { iconPath -> URL? in
                        let base = repo.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
                        return URL(string: "\(base)/\(iconPath)")
                    } ?? faviconUrl(from: entry.sources ?? [])

                    let installedManifest = installedManifests.first { $0.id == entry.id }

                    if let manifest = installedManifest {
                        let localCode = manifest.versionCode ?? versionInt(from: manifest.version)
                        let hasUpdate = entry.versionCode > localCode
                        // Always update repo info so force-reinstall works;
                        // mark as hasUpdate only when remote version is newer.
                        if let idx = result.firstIndex(where: { $0.id == entry.id }) {
                            result[idx] = ExtensionModel(
                                id: entry.id,
                                name: entry.name,
                                pkg: entry.id,
                                version: manifest.version,
                                versionCode: entry.versionCode,
                                lang: entry.lang,
                                nsfw: entry.nsfw == 1,
                                sources: entry.sources ?? [],
                                repoBaseUrl: repo.baseUrl,
                                scriptUrl: entry.scriptUrl,
                                iconUrl: iconUrl,
                                state: hasUpdate ? .hasUpdate(newVersion: entry.version) : .installed
                            )
                        }
                    } else if !result.contains(where: { $0.id == entry.id }) {
                        result.append(ExtensionModel(
                            id: entry.id,
                            name: entry.name,
                            pkg: entry.id,
                            version: entry.version,
                            versionCode: entry.versionCode,
                            lang: entry.lang,
                            nsfw: entry.nsfw == 1,
                            sources: entry.sources ?? [],
                            repoBaseUrl: repo.baseUrl,
                            scriptUrl: entry.scriptUrl,
                            iconUrl: iconUrl,
                            state: .available
                        ))
                    }
                }
                NSLog("[ExtensionManager] Fetched %d plugins from repo: %@", pluginEntries.count, repo.baseUrl)
                continue
            }

            // Fallback: legacy index.min.json format (stub-only, no JS plugin)
            do {
                let entries = try await repoService.fetchExtensionIndex(baseUrl: repo.baseUrl)
                for entry in entries {
                    let installedManifest = installedManifests.first { $0.id == entry.pkg }
                    let iconUrl = URL(string: "\(repo.baseUrl)/icon/\(entry.pkg).png")

                    if let manifest = installedManifest {
                        let localCode = manifest.versionCode ?? versionInt(from: manifest.version)
                        let hasUpdate = entry.code > localCode
                        if let idx = result.firstIndex(where: { $0.id == entry.pkg }) {
                            result[idx] = ExtensionModel(
                                id: entry.pkg,
                                name: entry.name,
                                pkg: entry.pkg,
                                version: manifest.version,
                                versionCode: entry.code,
                                lang: entry.lang,
                                nsfw: entry.nsfw == 1,
                                sources: entry.sources ?? [],
                                repoBaseUrl: repo.baseUrl,
                                scriptUrl: nil,
                                iconUrl: iconUrl,
                                state: hasUpdate ? .hasUpdate(newVersion: entry.version) : .installed
                            )
                        }
                    } else if !result.contains(where: { $0.id == entry.pkg }) {
                        result.append(ExtensionModel(
                            id: entry.pkg,
                            name: entry.name,
                            pkg: entry.pkg,
                            version: entry.version,
                            versionCode: entry.code,
                            lang: entry.lang,
                            nsfw: entry.nsfw == 1,
                            sources: entry.sources ?? [],
                            repoBaseUrl: repo.baseUrl,
                            scriptUrl: nil,
                            iconUrl: iconUrl,
                            state: .available
                        ))
                    }
                }
                NSLog("[ExtensionManager] Fetched %d entries from legacy repo: %@", entries.count, repo.baseUrl)
            } catch {
                NSLog("[ExtensionManager] Failed to fetch index from %@: %@", repo.baseUrl, error.localizedDescription)
            }
        }

        extensions = result.sorted { a, b in
            if a.state != .available && b.state == .available { return true }
            if a.state == .available && b.state != .available { return false }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    // MARK: - Install extension

    /// Install an extension by downloading its JS crawler script from the repo.
    /// Falls back to saving stub sources if no scriptUrl is available.
    func installExtension(_ ext: ExtensionModel) async throws {
        setExtensionState(pkg: ext.pkg, state: .installing)

        do {
            if let scriptUrl = ext.scriptUrl, let repoBaseUrl = ext.repoBaseUrl {
                // Download JS plugin script from repo
                let scriptData = try await repoService.downloadPluginScript(
                    baseUrl: repoBaseUrl, scriptUrl: scriptUrl
                )

                guard let script = String(data: scriptData, encoding: .utf8), !script.isEmpty else {
                    throw ExtensionRepoError.networkError("Empty script data")
                }

                // Save to plugins directory
                let pluginsDir = DiskUtil.pluginsDirectory()
                try FileManager.default.createDirectory(at: pluginsDir, withIntermediateDirectories: true)

                let jsFile = pluginsDir.appendingPathComponent("\(ext.pkg).js")
                try scriptData.write(to: jsFile)

                // Create and save manifest
                let manifest = PluginManifest(
                    id: ext.pkg,
                    name: ext.name,
                    version: ext.version,
                    versionCode: ext.versionCode,
                    lang: ext.lang,
                    nsfw: ext.nsfw,
                    script: "\(ext.pkg).js",
                    signature: "",
                    sources: ext.sources.isEmpty ? nil : ext.sources
                )
                let manifestFile = pluginsDir.appendingPathComponent("\(ext.pkg).json")
                let manifestData = try JSONEncoder().encode(manifest)
                try manifestData.write(to: manifestFile)

                // Auto-trust the downloaded plugin
                let hash = PluginVerifier.hash(of: scriptData)
                let versionCode = versionInt(from: ext.version)
                PluginTrustStore.shared.trust(pkg: ext.pkg, versionCode: versionCode, hash: hash)

                // Load and register with SourceManager
                if let source = pluginLoader.loadPlugin(at: jsFile) {
                    sourceManager.register(source: source)
                }
            } else {
                // No JS script available — save stub manifest
                let pluginsDir = DiskUtil.pluginsDirectory()
                try FileManager.default.createDirectory(at: pluginsDir, withIntermediateDirectories: true)

                let manifest = PluginManifest(
                    id: ext.pkg,
                    name: ext.name,
                    version: ext.version,
                    versionCode: ext.versionCode,
                    lang: ext.lang,
                    nsfw: ext.nsfw,
                    script: "\(ext.pkg).js",
                    signature: "",
                    sources: ext.sources.isEmpty ? nil : ext.sources
                )
                let manifestFile = pluginsDir.appendingPathComponent("\(ext.pkg).json")
                let manifestData = try JSONEncoder().encode(manifest)
                try manifestData.write(to: manifestFile)

                // Register stub sources
                for entry in ext.sources {
                    let stub = StubCatalogueSource(entry: entry)
                    sourceManager.register(source: stub)
                }
            }

            setExtensionState(pkg: ext.pkg, state: .installed)
        } catch {
            setExtensionState(pkg: ext.pkg, state: .available)
            throw error
        }
    }

    // MARK: - Update extension

    func updateExtension(_ ext: ExtensionModel) async throws {
        removeExtensionFiles(pkg: ext.pkg)
        try await installExtension(ext)
    }

    // MARK: - Force reinstall extension

    /// Force reinstall an already-installed extension: re-download the JS script from the repo,
    /// unregister old sources, reload fresh.
    func forceReinstallExtension(_ ext: ExtensionModel) async throws {
        setExtensionState(pkg: ext.pkg, state: .installing)

        do {
            // Unregister old sources
            for entry in ext.sources {
                sourceManager.unregisterSource(id: entry.id)
            }

            // If we have repo info, re-download from remote
            if let scriptUrl = ext.scriptUrl, let repoBaseUrl = ext.repoBaseUrl {
                removeExtensionFiles(pkg: ext.pkg)

                let scriptData = try await repoService.downloadPluginScript(
                    baseUrl: repoBaseUrl, scriptUrl: scriptUrl
                )

                guard let script = String(data: scriptData, encoding: .utf8), !script.isEmpty else {
                    throw ExtensionRepoError.networkError("Empty script data")
                }

                let pluginsDir = DiskUtil.pluginsDirectory()
                try FileManager.default.createDirectory(at: pluginsDir, withIntermediateDirectories: true)

                let jsFile = pluginsDir.appendingPathComponent("\(ext.pkg).js")
                try scriptData.write(to: jsFile)

                // Re-create manifest with the remote version
                let remoteVersion = ext.displayVersion.contains("→")
                    ? String(ext.displayVersion.split(separator: "→").last ?? Substring(ext.version)).trimmingCharacters(in: .whitespaces)
                    : ext.version
                let manifest = PluginManifest(
                    id: ext.pkg,
                    name: ext.name,
                    version: remoteVersion,
                    versionCode: ext.versionCode,
                    lang: ext.lang,
                    nsfw: ext.nsfw,
                    script: "\(ext.pkg).js",
                    signature: "",
                    sources: ext.sources.isEmpty ? nil : ext.sources
                )
                let manifestFile = pluginsDir.appendingPathComponent("\(ext.pkg).json")
                let manifestData = try JSONEncoder().encode(manifest)
                try manifestData.write(to: manifestFile)

                // Trust the new script
                let hash = PluginVerifier.hash(of: scriptData)
                let versionCode = versionInt(from: remoteVersion)
                PluginTrustStore.shared.trust(pkg: ext.pkg, versionCode: versionCode, hash: hash)

                // Reload plugin
                if let source = pluginLoader.loadPlugin(at: jsFile) {
                    sourceManager.register(source: source)
                }

                NSLog("[ExtensionManager] Force reinstalled %@ from repo", ext.pkg)
            } else {
                // No repo info — just reload from local disk
                let pluginsDir = DiskUtil.pluginsDirectory()
                let jsFile = pluginsDir.appendingPathComponent("\(ext.pkg).js")
                if FileManager.default.fileExists(atPath: jsFile.path) {
                    if let source = pluginLoader.loadPlugin(at: jsFile) {
                        sourceManager.register(source: source)
                    }
                }
                NSLog("[ExtensionManager] Force reloaded %@ from local disk", ext.pkg)
            }

            setExtensionState(pkg: ext.pkg, state: .installed)
        } catch {
            setExtensionState(pkg: ext.pkg, state: .installed)
            throw error
        }
    }

    // MARK: - Uninstall extension

    func uninstallExtension(_ ext: ExtensionModel) {
        // Unregister sources from SourceManager
        for entry in ext.sources {
            sourceManager.unregisterSource(id: entry.id)
        }

        removeExtensionFiles(pkg: ext.pkg)

        // Remove from list or mark as available
        if let idx = extensions.firstIndex(where: { $0.id == ext.pkg }) {
            if extensions[idx].repoBaseUrl != nil {
                extensions[idx] = ExtensionModel(
                    id: ext.id,
                    name: ext.name,
                    pkg: ext.pkg,
                    version: ext.version,
                    versionCode: ext.versionCode,
                    lang: ext.lang,
                    nsfw: ext.nsfw,
                    sources: ext.sources,
                    repoBaseUrl: ext.repoBaseUrl,
                    scriptUrl: ext.scriptUrl,
                    iconUrl: ext.iconUrl,
                    state: .available
                )
            } else {
                extensions.remove(at: idx)
            }
        }
    }

    // MARK: - Helpers

    private func removeExtensionFiles(pkg: String) {
        let pluginsDir = DiskUtil.pluginsDirectory()
        let jsFile = pluginsDir.appendingPathComponent("\(pkg).js")
        let manifestFile = pluginsDir.appendingPathComponent("\(pkg).json")
        try? FileManager.default.removeItem(at: jsFile)
        try? FileManager.default.removeItem(at: manifestFile)
    }

    private func loadInstalledManifests() -> [PluginManifest] {
        let pluginsDir = DiskUtil.pluginsDirectory()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: pluginsDir, includingPropertiesForKeys: nil
        ) else { return [] }

        return contents
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> PluginManifest? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(PluginManifest.self, from: data)
            }
    }

    private func setExtensionState(pkg: String, state: ExtensionModel.State) {
        if let idx = extensions.firstIndex(where: { $0.id == pkg }) {
            let old = extensions[idx]
            extensions[idx] = ExtensionModel(
                id: old.id,
                name: old.name,
                pkg: old.pkg,
                version: old.version,
                versionCode: old.versionCode,
                lang: old.lang,
                nsfw: old.nsfw,
                sources: old.sources,
                repoBaseUrl: old.repoBaseUrl,
                scriptUrl: old.scriptUrl,
                iconUrl: old.iconUrl,
                state: state
            )
        }
    }

    /// Generate a favicon URL from the first source's baseUrl.
    private func faviconUrl(from sources: [SourceIndexEntry]) -> URL? {
        guard let baseUrl = sources.first?.baseUrl else { return nil }
        let base = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return URL(string: "\(base)/favicon.ico")
    }

    private func versionInt(from version: String) -> Int {
        let parts = version.split(separator: ".").compactMap { Int($0) }
        switch parts.count {
        case 1: return parts[0]
        case 2: return parts[0] * 100 + parts[1]
        default:
            return (parts[0] * 10_000) + (parts.count > 1 ? parts[1] * 100 : 0) + (parts.count > 2 ? parts[2] : 0)
        }
    }
}
