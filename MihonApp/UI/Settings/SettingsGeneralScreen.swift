import SwiftUI
import MihonI18n

// MARK: - Supporting types

enum AppLanguage: String, CaseIterable, Identifiable {
    case systemDefault = "system"
    case english       = "en"
    case japanese      = "ja"
    case chineseSimp   = "zh-Hans"
    case chineseTrad   = "zh-Hant"
    case korean        = "ko"
    case french        = "fr"
    case german        = "de"
    case spanish       = "es"
    case portuguese    = "pt"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .systemDefault: return "System Default"
        case .english:       return "English"
        case .japanese:      return "日本語"
        case .chineseSimp:   return "简体中文"
        case .chineseTrad:   return "繁體中文"
        case .korean:        return "한국어"
        case .french:        return "Français"
        case .german:        return "Deutsch"
        case .spanish:       return "Español"
        case .portuguese:    return "Português"
        }
    }
}

enum DateFormatOption: String, CaseIterable, Identifiable {
    case mmddyyyy  = "MM/dd/yyyy"
    case ddmmyyyy  = "dd/MM/yyyy"
    case yyyymmdd  = "yyyy/MM/dd"
    case ddMMMMyyyy = "dd MMMM yyyy"

    var id: String { rawValue }

    var preview: String {
        let formatter = DateFormatter()
        formatter.dateFormat = rawValue
        return formatter.string(from: Date())
    }
}

enum StartingScreen: String, CaseIterable, Identifiable {
    case library  = "library"
    case updates  = "updates"
    case history  = "history"
    case browse   = "browse"
    case more     = "more"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .library:  return "Library"
        case .updates:  return "Updates"
        case .history:  return "History"
        case .browse:   return "Browse"
        case .more:     return "More"
        }
    }
}

// MARK: - View

struct SettingsGeneralScreen: View {

    @AppStorage(SettingsKeys.languagePreference)    private var language: String            = AppLanguage.systemDefault.rawValue
    @AppStorage(SettingsKeys.dateFormat)            private var dateFormat: String          = DateFormatOption.mmddyyyy.rawValue
    @AppStorage(SettingsKeys.confirmBeforeClosing)  private var confirmBeforeClosing: Bool  = false
    @AppStorage(SettingsKeys.defaultStartingScreen) private var startingScreen: String      = StartingScreen.library.rawValue

    var body: some View {
        List {
            // MARK: Language
            Section {
                Picker(MR.strings.generalLanguage, selection: $language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
            .onChange(of: language) { newLang in
                let code = newLang == "system" ? nil : newLang
                LanguageManager.shared.currentLanguage = code
            }
            } header: {
                Text(MR.strings.generalDisplay)
            }

            // MARK: Date Format
            Section {
                Picker(MR.strings.generalDateFormat, selection: $dateFormat) {
                    ForEach(DateFormatOption.allCases) { option in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.rawValue)
                                .font(.body)
                            Text(option.preview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(option.rawValue)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            // MARK: Navigation
            Section {
                Picker(MR.strings.generalDefaultScreen, selection: $startingScreen) {
                    ForEach(StartingScreen.allCases) { screen in
                        Text(screen.displayName).tag(screen.rawValue)
                    }
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text(MR.strings.generalNavigation)
            }

            // MARK: Behaviour
            Section {
                Toggle(isOn: $confirmBeforeClosing) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.generalConfirmClose)
                        Text(MR.strings.generalConfirmCloseDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(MR.strings.generalBehaviour)
            }
        }
        .navigationTitle(MR.strings.settingsGeneral)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsGeneralScreen()
    }
}
