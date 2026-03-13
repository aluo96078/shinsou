import Foundation
import MihonCore
import MihonSourceAPI
import MihonSourceLocal

@MainActor
final class SourceManager: ObservableObject {
    static let shared = SourceManager()

    @Published private(set) var sources: [Int64: any Source] = [:]
    @Published private(set) var catalogueSources: [any CatalogueSource] = []

    private init() {
        registerBuiltInSources()
    }

    private func registerBuiltInSources() {
        // Local source
        let local = LocalSource()
        register(source: local)

        // Load JS plugins (user-installed / transpiled)
        let plugins = PluginLoader.shared.loadAllPlugins()
        for plugin in plugins {
            register(source: plugin)
        }

        // Load stub sources from installed extension manifests
        loadInstalledExtensionSources()
    }

    /// Scan plugins directory for installed manifests and register stub sources.
    private func loadInstalledExtensionSources() {
        let pluginsDir = DiskUtil.pluginsDirectory()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: pluginsDir, includingPropertiesForKeys: nil
        ) else { return }

        for url in contents where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data),
                  let entries = manifest.sources else { continue }

            for entry in entries {
                // Avoid re-registering if already loaded via JS plugins
                if sources[entry.id] == nil {
                    let stub = StubCatalogueSource(entry: entry)
                    register(source: stub)
                }
            }
        }
    }

    func register(source: any Source) {
        sources[source.id] = source
        if let catalogue = source as? any CatalogueSource {
            catalogueSources.append(catalogue)
        }
    }

    func getSource(id: Int64) -> (any Source)? {
        sources[id]
    }

    func getCatalogueSource(id: Int64) -> (any CatalogueSource)? {
        sources[id] as? any CatalogueSource
    }

    func getCatalogueSources(enabledLanguages: Set<String>? = nil) -> [any CatalogueSource] {
        if let langs = enabledLanguages {
            return catalogueSources.filter { langs.contains($0.lang) }
        }
        return catalogueSources
    }

    /// Remove all sources whose name starts with the given extension name.
    /// Called when an extension is uninstalled from the device.
    func unregisterSources(forExtensionName extensionName: String) {
        let toRemove = catalogueSources.filter { $0.name.hasPrefix(extensionName) }
        for source in toRemove {
            sources.removeValue(forKey: source.id)
        }
        catalogueSources.removeAll { $0.name.hasPrefix(extensionName) }
    }

    /// Remove a single source by its id.
    func unregisterSource(id: Int64) {
        sources.removeValue(forKey: id)
        catalogueSources.removeAll { $0.id == id }
    }
}
