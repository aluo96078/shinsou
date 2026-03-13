import SwiftUI
import MihonI18n

@main
struct MihonApp: App {
    @StateObject private var container = DIContainer.shared

    /// Tracks language changes to force a full view refresh.
    @State private var languageRefreshId = UUID()

    init() {
        // Apply saved language preference on launch
        let saved = UserDefaults.standard.string(forKey: "settings.general.languagePreference") ?? "system"
        LanguageManager.shared.currentLanguage = saved == "system" ? nil : saved
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(container)
                .id(languageRefreshId)
                .onReceive(NotificationCenter.default.publisher(for: LanguageManager.languageDidChangeNotification)) { _ in
                    languageRefreshId = UUID()
                }
        }
    }
}
