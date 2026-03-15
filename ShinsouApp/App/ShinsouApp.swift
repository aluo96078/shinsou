import SwiftUI
import ShinsouI18n

@main
struct ShinsouApp: App {
    @StateObject private var container = DIContainer.shared

    /// Tracks language changes to force a full view refresh.
    @State private var languageRefreshId = UUID()

    init() {
        // Apply saved language preference on launch
        let saved = UserDefaults.standard.string(forKey: "settings.general.languagePreference") ?? "system"
        LanguageManager.shared.currentLanguage = saved == "system" ? nil : saved

        // 音量鍵翻頁：設定開啟時提前安裝 HUD 抑制，避免首次按下出現系統音量條
        if UserDefaults.standard.bool(forKey: SettingsKeys.volumeKeys) {
            // 延遲到視窗就緒後安裝
            DispatchQueue.main.async {
                VolumeButtonHandler.shared.installHUDSuppression()
            }
        }
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
