import SwiftUI
import MihonI18n

struct SettingsScreen: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink { SettingsGeneralScreen() } label: {
                    Label(MR.strings.settingsGeneral, systemImage: "gear")
                }
                NavigationLink { SettingsAppearanceScreen() } label: {
                    Label(MR.strings.settingsAppearance, systemImage: "paintbrush")
                }
                NavigationLink { SettingsLibraryScreen() } label: {
                    Label(MR.strings.settingsLibrary, systemImage: "books.vertical")
                }
                NavigationLink { SettingsReaderScreen() } label: {
                    Label(MR.strings.settingsReader, systemImage: "book")
                }
                NavigationLink { SettingsDownloadsScreen() } label: {
                    Label(MR.strings.settingsDownloads, systemImage: "arrow.down.circle")
                }
                NavigationLink { SettingsTrackingScreen() } label: {
                    Label(MR.strings.settingsTracking, systemImage: "chart.bar")
                }
                NavigationLink { SettingsBrowseScreen() } label: {
                    Label(MR.strings.settingsBrowse, systemImage: "globe")
                }
                NavigationLink { SettingsBackupScreen() } label: {
                    Label(MR.strings.settingsBackup, systemImage: "arrow.triangle.2.circlepath")
                }
                NavigationLink { SettingsSecurityScreen() } label: {
                    Label(MR.strings.settingsSecurity, systemImage: "lock")
                }
                NavigationLink { SettingsAdvancedScreen() } label: {
                    Label(MR.strings.settingsAdvanced, systemImage: "wrench")
                }
            }
            .navigationTitle(MR.strings.settingsTitle)
        }
    }
}

#Preview {
    SettingsScreen()
}
