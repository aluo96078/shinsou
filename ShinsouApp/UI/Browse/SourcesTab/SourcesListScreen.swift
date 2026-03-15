import SwiftUI
import ShinsouSourceAPI
import ShinsouI18n
import NukeUI

// MARK: - SourcePinStore

/// Manages pinned source IDs persisted in UserDefaults.
final class SourcePinStore: ObservableObject {
    static let shared = SourcePinStore()

    @Published private(set) var pinnedIds: Set<Int64> = []

    private let key = SettingsKeys.pinnedSourceIds

    private init() {
        load()
    }

    func isPinned(_ id: Int64) -> Bool {
        pinnedIds.contains(id)
    }

    func pin(_ id: Int64) {
        pinnedIds.insert(id)
        save()
    }

    func unpin(_ id: Int64) {
        pinnedIds.remove(id)
        save()
    }

    func toggle(_ id: Int64) {
        if isPinned(id) { unpin(id) } else { pin(id) }
    }

    // MARK: - Persistence

    private func load() {
        let stored = UserDefaults.standard.array(forKey: key) as? [Int64] ?? []
        pinnedIds = Set(stored)
    }

    private func save() {
        UserDefaults.standard.set(Array(pinnedIds), forKey: key)
    }
}

// MARK: - LanguageFilterStore

/// Manages the set of enabled language codes persisted in UserDefaults.
final class LanguageFilterStore: ObservableObject {
    static let shared = LanguageFilterStore()

    @Published private(set) var enabledLanguages: Set<String> = []

    /// True when the store has been loaded but no languages were previously saved —
    /// treat "empty" as "show all" so the first launch is not blank.
    private(set) var isAllEnabled: Bool = true

    private let key = SettingsKeys.enabledLanguages

    private init() {
        load()
    }

    func isEnabled(_ lang: String) -> Bool {
        isAllEnabled || enabledLanguages.contains(lang)
    }

    func toggle(_ lang: String) {
        if enabledLanguages.contains(lang) {
            enabledLanguages.remove(lang)
        } else {
            enabledLanguages.insert(lang)
        }
        isAllEnabled = enabledLanguages.isEmpty
        save()
    }

    func enableAll(_ langs: Set<String>) {
        enabledLanguages = langs
        isAllEnabled = false
        save()
    }

    func disableAll() {
        enabledLanguages = []
        isAllEnabled = true
        save()
    }

    // MARK: - Persistence

    private func load() {
        if let stored = UserDefaults.standard.array(forKey: key) as? [String] {
            enabledLanguages = Set(stored)
            isAllEnabled = stored.isEmpty
        }
    }

    private func save() {
        UserDefaults.standard.set(Array(enabledLanguages), forKey: key)
    }
}

// MARK: - Language Filter Sheet

struct LanguageFilterSheet: View {
    @ObservedObject var langStore: LanguageFilterStore
    let availableLanguages: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(MR.strings.browseEnableAll) {
                        langStore.enableAll(Set(availableLanguages))
                    }
                    Button(MR.strings.browseShowAllReset) {
                        langStore.disableAll()
                    }
                    .foregroundStyle(.secondary)
                }

                Section(MR.strings.browseLanguages) {
                    ForEach(availableLanguages.sorted(), id: \.self) { lang in
                        Button {
                            langStore.toggle(lang)
                        } label: {
                            HStack {
                                Text(Locale.current.localizedString(forLanguageCode: lang) ?? lang.uppercased())
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(lang.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if langStore.isAllEnabled || langStore.enabledLanguages.contains(lang) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(MR.strings.browseFilterLanguages)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(MR.strings.commonDone) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Source Row

private struct SourceRow: View {
    let source: any CatalogueSource
    let isPinned: Bool

    var body: some View {
        HStack {
            SourceIconView(source: source)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.body)
                Text(Locale.current.localizedString(forLanguageCode: source.lang) ?? source.lang.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
            }

            if source.supportsLatest {
                Text(MR.strings.browseLatest)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .foregroundStyle(.green)
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - SourcesTabContent

/// Embeddable sources list content (without its own NavigationStack).
/// Used inside BrowseScreen's shared NavigationStack.
struct SourcesTabContent: View {
    @ObservedObject private var sourceManager = SourceManager.shared
    @ObservedObject private var pinStore = SourcePinStore.shared
    @ObservedObject private var langStore = LanguageFilterStore.shared

    // MARK: - Computed sources

    private var filteredSources: [any CatalogueSource] {
        sourceManager.catalogueSources.filter { langStore.isEnabled($0.lang) }
    }

    private var pinnedSources: [any CatalogueSource] {
        filteredSources.filter { pinStore.isPinned($0.id) }
            .sorted { $0.name < $1.name }
    }

    /// Sources grouped by language, sorted alphabetically within each group.
    private var sourcesByLanguage: [(lang: String, sources: [any CatalogueSource])] {
        let unpinned = filteredSources.filter { !pinStore.isPinned($0.id) }
        let grouped = Dictionary(grouping: unpinned) { $0.lang }
        return grouped
            .map { lang, srcs in (lang: lang, sources: srcs.sorted { $0.name < $1.name }) }
            .sorted { lhs, rhs in
                let lName = Locale.current.localizedString(forLanguageCode: lhs.lang) ?? lhs.lang
                let rName = Locale.current.localizedString(forLanguageCode: rhs.lang) ?? rhs.lang
                return lName < rName
            }
    }

    // MARK: - Body

    var body: some View {
        List {
            // Pinned section
            if !pinnedSources.isEmpty {
                Section(MR.strings.sourcesPinned) {
                    ForEach(pinnedSources, id: \.id) { source in
                        sourceLink(source)
                            .contextMenu { contextMenuItems(source) }
                    }
                }
            }

            // Language-grouped sections
            ForEach(sourcesByLanguage, id: \.lang) { group in
                Section(
                    header: Text(
                        Locale.current.localizedString(forLanguageCode: group.lang) ?? group.lang.uppercased()
                    )
                ) {
                    ForEach(group.sources, id: \.id) { source in
                        sourceLink(source)
                            .contextMenu { contextMenuItems(source) }
                    }
                }
            }
        }
        .navigationDestination(for: Int64.self) { sourceId in
            BrowseSourceScreen(sourceId: sourceId)
        }
        .navigationDestination(for: SourcePreferencesDestination.self) { dest in
            if let configurable = dest.source {
                SourcePreferencesScreen(source: configurable)
            } else {
                Text(MR.strings.sourcesNotFound)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sourceLink(_ source: any CatalogueSource) -> some View {
        NavigationLink(value: source.id) {
            SourceRow(source: source, isPinned: pinStore.isPinned(source.id))
        }
    }

    @ViewBuilder
    private func contextMenuItems(_ source: any CatalogueSource) -> some View {
        let pinned = pinStore.isPinned(source.id)
        Button {
            pinStore.toggle(source.id)
        } label: {
            Label(
                pinned ? "Unpin" : "Pin",
                systemImage: pinned ? "pin.slash" : "pin"
            )
        }

        Divider()

        NavigationLink(value: source.id) {
            Label(MR.strings.browseSources, systemImage: "books.vertical")
        }

        if let configurable = source as? any ConfigurableSource {
            NavigationLink(value: SourcePreferencesDestination(source: configurable)) {
                Label(MR.strings.browsePreferences, systemImage: "gearshape")
            }
        }
    }
}

// MARK: - Navigation destination wrapper

/// Hashable wrapper used as NavigationStack destination value for source preferences.
struct SourcePreferencesDestination: Hashable {
    let sourceId: Int64
    let sourceName: String

    // Retain the source only for navigation; it will be fetched from SourceManager.
    private let _source: AnyObject?

    init(source: any ConfigurableSource) {
        self.sourceId = source.id
        self.sourceName = source.name
        self._source = source as AnyObject
    }

    var source: (any ConfigurableSource)? {
        _source as? any ConfigurableSource
    }

    static func == (lhs: SourcePreferencesDestination, rhs: SourcePreferencesDestination) -> Bool {
        lhs.sourceId == rhs.sourceId
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(sourceId)
    }
}

// MARK: - Source Icon View

/// Displays a favicon from the source's baseUrl, falling back to a globe icon.
private struct SourceIconView: View {
    let source: any CatalogueSource

    private var faviconUrl: URL? {
        guard let jsProxy = source as? JSSourceProxy else { return nil }
        let base = jsProxy.baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return URL(string: "\(base)/favicon.ico")
    }

    var body: some View {
        LazyImage(url: faviconUrl) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            } else {
                Image(systemName: "globe")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            }
        }
        .background(Color.accentColor.opacity(0.1))
    }
}
