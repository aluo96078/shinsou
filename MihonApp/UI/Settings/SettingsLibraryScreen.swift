import SwiftUI
import MihonDomain

// MARK: - Supporting types

enum CategoryUpdateBehaviour: String, CaseIterable, Identifiable {
    case all      = "all"
    case selected = "selected"
    case none     = "none"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:      return "All Categories"
        case .selected: return "Selected Categories Only"
        case .none:     return "Disabled"
        }
    }
}

struct GlobalUpdateRestrictions: OptionSet {
    let rawValue: Int

    static let wifiOnly    = GlobalUpdateRestrictions(rawValue: 1 << 0)
    static let chargingOnly = GlobalUpdateRestrictions(rawValue: 1 << 1)
}

// MARK: - View

struct SettingsLibraryScreen: View {

    @AppStorage(SettingsKeys.defaultCategory)          private var defaultCategory: String      = "Default"
    @AppStorage(SettingsKeys.categoryUpdateBehaviour)  private var updateBehaviour: String      = CategoryUpdateBehaviour.all.rawValue
    @AppStorage(SettingsKeys.autoRefreshMetadata)      private var autoRefreshMetadata: Bool    = false

    @State private var availableCategories: [MihonDomain.Category] = []

    // Update restrictions stored as a bitmask integer
    @AppStorage(SettingsKeys.globalUpdateRestrictions) private var restrictionsMask: Int = 0

    private var wifiOnlyBinding: Binding<Bool> {
        Binding(
            get: { restrictionsMask & GlobalUpdateRestrictions.wifiOnly.rawValue != 0 },
            set: { enabled in
                if enabled {
                    restrictionsMask |= GlobalUpdateRestrictions.wifiOnly.rawValue
                } else {
                    restrictionsMask &= ~GlobalUpdateRestrictions.wifiOnly.rawValue
                }
            }
        )
    }

    private var chargingOnlyBinding: Binding<Bool> {
        Binding(
            get: { restrictionsMask & GlobalUpdateRestrictions.chargingOnly.rawValue != 0 },
            set: { enabled in
                if enabled {
                    restrictionsMask |= GlobalUpdateRestrictions.chargingOnly.rawValue
                } else {
                    restrictionsMask &= ~GlobalUpdateRestrictions.chargingOnly.rawValue
                }
            }
        )
    }

    var body: some View {
        List {
            // MARK: Categories
            Section {
                Picker("Default Category", selection: $defaultCategory) {
                    Text("Default").tag("Default")
                    ForEach(availableCategories) { cat in
                        Text(cat.name).tag(cat.name)
                    }
                    Text("Always Ask").tag("__ask__")
                }
                .pickerStyle(.navigationLink)

                Picker("Category Updates", selection: $updateBehaviour) {
                    ForEach(CategoryUpdateBehaviour.allCases) { option in
                        Text(option.displayName).tag(option.rawValue)
                    }
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text("Categories")
            } footer: {
                Text("New manga added to your library will be placed in the default category.")
            }

            // MARK: Global Update
            Section {
                Toggle(isOn: wifiOnlyBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Wi-Fi Only")
                        Text("Only run the global update when connected to Wi-Fi.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: chargingOnlyBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Charging Only")
                        Text("Only run the global update when the device is charging.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Global Update Restrictions")
            } footer: {
                Text("The global update will be skipped if the active restrictions are not met.")
            }

            // MARK: Metadata
            Section {
                Toggle(isOn: $autoRefreshMetadata) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Refresh Metadata")
                        Text("Automatically update manga cover art, description, and genres during the global update.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Metadata")
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let repo = DIContainer.shared.categoryRepository
            if let cats = try? await repo.getAll() {
                availableCategories = cats.filter { !$0.isSystemCategory }.sorted { $0.sort < $1.sort }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsLibraryScreen()
    }
}
