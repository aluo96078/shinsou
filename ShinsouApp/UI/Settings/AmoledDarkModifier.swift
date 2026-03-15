import SwiftUI

// MARK: - Environment key

private struct AmoledDarkKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    /// `true` when the AMOLED pure-black theme is active AND the device is currently in dark mode.
    var isAmoledDark: Bool {
        get { self[AmoledDarkKey.self] }
        set { self[AmoledDarkKey.self] = newValue }
    }
}

// MARK: - ViewModifier

/// Applies the AMOLED dark theme when the user has enabled it in settings and the system is
/// currently using the dark color scheme. In that state, every `.background` call that relies
/// on `Color(.systemBackground)` / `.primary` / etc. will see pure `#000000` instead of the
/// system's default dark-grey background.
struct AmoledDarkModifier: ViewModifier {
    @AppStorage(SettingsKeys.amoledDark) private var amoledEnabled: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    private var isActive: Bool { amoledEnabled && colorScheme == .dark }

    func body(content: Content) -> some View {
        content
            .environment(\.isAmoledDark, isActive)
            // Override the semantic background tokens used by SwiftUI built-in components
            .background(isActive ? Color.black : Color(.systemBackground))
            .tint(isActive ? nil : nil) // tint is preserved; only background changes
    }
}

extension View {
    /// Activates the AMOLED pure-black background when enabled in Appearance settings.
    func amoledDarkBackground() -> some View {
        modifier(AmoledDarkModifier())
    }
}

// MARK: - Convenience background modifier

/// Use this on individual views that need to respect the AMOLED dark override.
///
///     myView.amoledAdaptiveBackground(.systemBackground)
struct AmoledAdaptiveBackgroundModifier: ViewModifier {
    @Environment(\.isAmoledDark) private var isAmoledDark
    let fallback: Color

    func body(content: Content) -> some View {
        content.background(isAmoledDark ? Color.black : fallback)
    }
}

extension View {
    /// Applies `Color.black` in AMOLED dark mode, `fallback` otherwise.
    func amoledAdaptiveBackground(_ fallback: Color = Color(.systemBackground)) -> some View {
        modifier(AmoledAdaptiveBackgroundModifier(fallback: fallback))
    }
}
