import SwiftUI
import ShinsouI18n

// MARK: - Supporting types

enum AppTheme: String, CaseIterable, Identifiable {
    case system    = "system"
    case light     = "light"
    case dark      = "dark"
    case amoledDark = "amoled_dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:     return "System Default"
        case .light:      return "Light"
        case .dark:       return "Dark"
        case .amoledDark: return "AMOLED Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:              return nil
        case .light:               return .light
        case .dark, .amoledDark:   return .dark
        }
    }

    var icon: String {
        switch self {
        case .system:     return "circle.lefthalf.filled"
        case .light:      return "sun.max"
        case .dark:       return "moon"
        case .amoledDark: return "moon.fill"
        }
    }
}

enum TimestampFormatOption: String, CaseIterable, Identifiable {
    case absolute = "absolute"
    case relative = "relative"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .absolute: return "Absolute (e.g. Jan 1, 2024)"
        case .relative: return "Relative (e.g. 3 days ago)"
        }
    }
}

// MARK: - Tint colour catalogue

private struct TintOption: Identifiable {
    let id: String
    let color: Color

    static let palette: [TintOption] = [
        TintOption(id: "blue",   color: .blue),
        TintOption(id: "indigo", color: .indigo),
        TintOption(id: "purple", color: .purple),
        TintOption(id: "pink",   color: .pink),
        TintOption(id: "red",    color: .red),
        TintOption(id: "orange", color: .orange),
        TintOption(id: "yellow", color: .yellow),
        TintOption(id: "green",  color: .green),
        TintOption(id: "teal",   color: .teal),
        TintOption(id: "cyan",   color: .cyan),
    ]
}

// MARK: - View

struct SettingsAppearanceScreen: View {

    @AppStorage(SettingsKeys.appTheme)           private var theme: String            = AppTheme.system.rawValue
    @AppStorage(SettingsKeys.appTintColor)       private var tintColorId: String      = "blue"
    @AppStorage(SettingsKeys.relativeTimestamps) private var relativeTimestamps: Bool = false
    @AppStorage(SettingsKeys.amoledDark)         private var amoledDark: Bool         = false

    var body: some View {
        List {
            // MARK: Theme
            Section {
                ForEach(AppTheme.allCases) { option in
                    Button {
                        theme = option.rawValue
                        // Mirror AMOLED state into its own key so other views can observe it
                        amoledDark = (option == .amoledDark)
                    } label: {
                        HStack {
                            Image(systemName: option.icon)
                                .frame(width: 24)
                                .foregroundStyle(theme == option.rawValue ? Color.accentColor : Color.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.displayName)
                                    .foregroundStyle(.primary)
                                if option == .amoledDark {
                                    Text(MR.strings.appearanceOledDesc)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if theme == option.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            } header: {
                Text(MR.strings.appearanceTheme)
            }

            // MARK: Tint colour
            Section {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5),
                    spacing: 12
                ) {
                    ForEach(TintOption.palette) { option in
                        Button {
                            tintColorId = option.id
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 36, height: 36)
                                if tintColorId == option.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text(MR.strings.appearanceTintColor)
            } footer: {
                Text(MR.strings.appearanceTintDesc)
            }

            // MARK: Timestamps
            Section {
                Toggle(isOn: $relativeTimestamps) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.appearanceRelativeTimestamps)
                        Text("Show dates as \"3 days ago\" instead of exact dates.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(MR.strings.appearanceTimestamps)
            }
        }
        .navigationTitle(MR.strings.settingsAppearance)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsAppearanceScreen()
    }
}
