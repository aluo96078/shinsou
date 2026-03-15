import SwiftUI
import ShinsouI18n
import UserNotifications

// MARK: - OnboardingScreen

struct OnboardingScreen: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompleted = false
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            WelcomePage(onNext: { currentPage = 1 })
                .tag(0)
            SourcesPage(onNext: { currentPage = 2 })
                .tag(1)
            LibraryPage(onNext: { currentPage = 3 })
                .tag(2)
            GetStartedPage(onComplete: { hasCompleted = true })
                .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - OnboardingPage (base layout)

private struct OnboardingPage<Actions: View>: View {
    let symbol: String
    let symbolColor: Color
    let title: String
    let description: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustration
            ZStack {
                Circle()
                    .fill(symbolColor.opacity(0.12))
                    .frame(width: 180, height: 180)
                Image(systemName: symbol)
                    .font(.system(size: 80, weight: .light))
                    .foregroundStyle(symbolColor)
            }
            .padding(.bottom, 48)

            // Text content
            VStack(spacing: 16) {
                Text(title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 32)

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                actions()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 56)
        }
    }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingPage(
            symbol: "book.closed.fill",
            symbolColor: Color.accentColor,
            title: "Welcome to Shinsou",
            description: "Your ultimate manga reading companion. Discover, collect, and read manga from hundreds of sources — all in one place."
        ) {
            OnboardingButton(title: "Get Started", style: .primary, action: onNext)
        }
    }
}

// MARK: - Page 2: Sources

private struct SourcesPage: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingPage(
            symbol: "globe",
            symbolColor: .blue,
            title: "Browse & Install Sources",
            description: "Browse hundreds of manga sources from around the world. Install extensions to add new sources and keep them updated with one tap."
        ) {
            VStack(spacing: 10) {
                FeatureRow(icon: "puzzlepiece.extension", text: "Install extensions for any source")
                FeatureRow(icon: "arrow.down.circle", text: "Download chapters for offline reading")
                FeatureRow(icon: "magnifyingglass", text: "Search across all sources at once")
            }
            .padding(.bottom, 16)

            OnboardingButton(title: "Next", style: .primary, action: onNext)
        }
    }
}

// MARK: - Page 3: Library

private struct LibraryPage: View {
    let onNext: () -> Void

    var body: some View {
        OnboardingPage(
            symbol: "books.vertical.fill",
            symbolColor: .orange,
            title: "Organise Your Library",
            description: "Keep track of all the manga you love. Organise with categories, sync reading progress with trackers, and filter by status."
        ) {
            VStack(spacing: 10) {
                FeatureRow(icon: "folder", text: "Create categories to stay organised")
                FeatureRow(icon: "chart.bar", text: "Track progress on AniList, MAL & more")
                FeatureRow(icon: "line.3.horizontal.decrease.circle", text: "Filter by status, read count, and genre")
            }
            .padding(.bottom, 16)

            OnboardingButton(title: "Next", style: .primary, action: onNext)
        }
    }
}

// MARK: - Page 4: Get Started (permissions)

private struct GetStartedPage: View {
    let onComplete: () -> Void

    @State private var notificationsGranted: Bool? = nil
    @State private var isRequestingPermissions = false

    var body: some View {
        OnboardingPage(
            symbol: "checkmark.seal.fill",
            symbolColor: .green,
            title: "You're All Set!",
            description: "Optionally allow notifications so Shinsou can let you know when new chapters arrive and downloads complete."
        ) {
            // Notification permission row
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(notificationIconColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: notificationIconName)
                        .font(.title3)
                        .foregroundStyle(notificationIconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(MR.strings.onboardingNotifications)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(notificationStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if notificationsGranted == nil {
                    Button("Allow") {
                        requestNotifications()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .disabled(isRequestingPermissions)
                }
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

            OnboardingButton(title: "Start Reading", style: .primary, action: onComplete)
                .padding(.top, 4)

            if notificationsGranted == nil {
                Button("Skip") {
                    onComplete()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .task {
            await checkExistingNotificationPermission()
        }
    }

    // MARK: - Helpers

    private var notificationIconName: String {
        switch notificationsGranted {
        case true: return "bell.badge.fill"
        case false: return "bell.slash"
        default: return "bell"
        }
    }

    private var notificationIconColor: Color {
        switch notificationsGranted {
        case true: return .green
        case false: return .secondary
        default: return Color.accentColor
        }
    }

    private var notificationStatusText: String {
        switch notificationsGranted {
        case true: return "Enabled — you'll be notified of new chapters"
        case false: return "Denied — enable in Settings > Shinsou"
        default: return "Get notified when new chapters arrive"
        }
    }

    private func checkExistingNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationsGranted = true
        case .denied:
            notificationsGranted = false
        case .notDetermined:
            notificationsGranted = nil
        @unknown default:
            notificationsGranted = nil
        }
    }

    private func requestNotifications() {
        isRequestingPermissions = true
        Task {
            let granted = await NotificationManager.shared.requestPermission()
            await MainActor.run {
                notificationsGranted = granted
                isRequestingPermissions = false
                if granted {
                    NotificationManager.shared.registerCategories()
                }
            }
        }
    }
}

// MARK: - Reusable subviews

private struct OnboardingButton: View {
    enum Style { case primary, secondary }

    let title: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(style == .primary ? Color.accentColor : Color(.systemFill))
                .foregroundStyle(style == .primary ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingScreen()
}
