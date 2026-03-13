import Foundation
import MihonSourceAPI
import MihonCore

final class PluginLoader {
    static let shared = PluginLoader()

    private init() {}

    // MARK: - Load all plugins

    /// Load all plugins from the plugins directory.
    /// Plugins that fail signature/hash verification are skipped with a warning log.
    func loadAllPlugins() -> [JSSourceProxy] {
        // Clean up legacy bundled plugins that are no longer shipped
        cleanupLegacyBundledPlugins()

        var sources: [JSSourceProxy] = []
        var loadedIds: Set<Int64> = []

        // Load from plugins directory (user-installed / transpiled)
        let pluginsDir = DiskUtil.pluginsDirectory()
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: pluginsDir, includingPropertiesForKeys: nil
        ) {
            for item in contents where item.pathExtension == "js" {
                if let source = loadPlugin(at: item) {
                    sources.append(source)
                    loadedIds.insert(source.id)
                }
            }
        }

        return sources
    }

    /// Remove legacy bundled plugins that were previously shipped with the app
    /// but are no longer included.
    func cleanupLegacyBundledPlugins() {
        let pluginsDir = DiskUtil.pluginsDirectory()
        // Both short names and full pkg names to cover all file naming patterns
        let legacyPlugins = [
            "hanime1",
            "eu.kanade.tachiyomi.extension.zh.hanime1"
        ]

        for name in legacyPlugins {
            let jsFile = pluginsDir.appendingPathComponent("\(name).js")
            let jsonFile = pluginsDir.appendingPathComponent("\(name).json")
            var removed = false
            if FileManager.default.fileExists(atPath: jsFile.path) {
                try? FileManager.default.removeItem(at: jsFile)
                removed = true
            }
            if FileManager.default.fileExists(atPath: jsonFile.path) {
                try? FileManager.default.removeItem(at: jsonFile)
                removed = true
            }
            if removed {
                NSLog("[PluginLoader] Removed legacy bundled plugin: \(name)")
            }
        }
    }

    // MARK: - Load single plugin

    /// Load a single plugin from a file URL.
    /// Returns `nil` and logs a warning if verification fails.
    func loadPlugin(at url: URL) -> JSSourceProxy? {
        // Try to load manifest from companion .json file
        let manifestUrl = url.deletingPathExtension().appendingPathExtension("json")
        let manifest: PluginManifest

        if let manifestData = try? Data(contentsOf: manifestUrl),
           let decoded = try? JSONDecoder().decode(PluginManifest.self, from: manifestData) {
            manifest = decoded
        } else {
            // Create default manifest from filename; unsigned plugins still pass verification
            // if already in the trust store.
            let name = url.deletingPathExtension().lastPathComponent
            manifest = PluginManifest(
                id: name,
                name: name,
                version: "1.0",
                lang: "en",
                nsfw: false,
                script: url.lastPathComponent,
                signature: ""
            )
        }

        // --- Verification ---
        do {
            try PluginVerifier.verifyFile(at: url, manifest: manifest)
        } catch {
            NSLog("[PluginLoader] Skipping plugin '\(manifest.name)' — verification failed: \(error.localizedDescription)")
            return nil
        }

        guard let script = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return JSSourceProxy(scriptContent: script, manifest: manifest)
    }

    // MARK: - Install plugin from remote URL

    /// Download, verify, persist and load a plugin from a remote URL.
    /// - Parameters:
    ///   - remoteUrl:              URL of the `.js` file to fetch.
    ///   - manifest:               Pre-fetched manifest describing the plugin.
    ///   - signingKeyFingerprint:  Optional fingerprint from the `ExtensionRepo` for cross-checking.
    func installPlugin(
        from remoteUrl: URL,
        manifest: PluginManifest,
        signingKeyFingerprint: String? = nil
    ) async throws -> JSSourceProxy {
        let (data, _) = try await URLSession.shared.data(from: remoteUrl)

        guard let script = String(data: data, encoding: .utf8) else {
            throw JSPluginError.scriptLoadFailed
        }

        // Full verification before writing to disk.
        do {
            try PluginVerifier.verify(
                data: data,
                manifest: manifest,
                signingKeyFingerprint: signingKeyFingerprint
            )
        } catch {
            throw JSPluginError.signatureInvalid
        }

        // Save to plugins directory
        let pluginsDir = DiskUtil.pluginsDirectory()
        try FileManager.default.createDirectory(at: pluginsDir, withIntermediateDirectories: true)

        let scriptUrl = pluginsDir.appendingPathComponent(manifest.script)
        try data.write(to: scriptUrl)

        // Save manifest
        let manifestUrl = scriptUrl.deletingPathExtension().appendingPathExtension("json")
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: manifestUrl)

        guard let source = JSSourceProxy(scriptContent: script, manifest: manifest) else {
            throw JSPluginError.scriptLoadFailed
        }

        return source
    }

    /// Uninstall a plugin
    func uninstallPlugin(manifest: PluginManifest) {
        let pluginsDir = DiskUtil.pluginsDirectory()
        let scriptUrl = pluginsDir.appendingPathComponent(manifest.script)
        let manifestUrl = scriptUrl.deletingPathExtension().appendingPathExtension("json")

        try? FileManager.default.removeItem(at: scriptUrl)
        try? FileManager.default.removeItem(at: manifestUrl)
    }
}
