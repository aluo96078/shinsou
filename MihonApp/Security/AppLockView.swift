import SwiftUI

// MARK: - AppLockView

/// Full-screen lock overlay shown when `AppLockManager.isLocked` is `true`.
struct AppLockView: View {

    @ObservedObject var lockManager: AppLockManager

    // MARK: - Body

    var body: some View {
        ZStack {
            // Solid background so the underlying content is fully obscured.
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Lock icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                // Title
                Text("Shinsou is Locked")
                    .font(.title2.bold())

                // Unlock button
                Button {
                    Task { await lockManager.authenticate() }
                } label: {
                    Label(
                        "Unlock with \(lockManager.biometricTypeName)",
                        systemImage: biometricIcon
                    )
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.tint, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }
                .disabled(lockManager.isAuthenticating)

                // Secondary passcode hint while authentication is in progress
                if lockManager.isAuthenticating {
                    ProgressView()
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .onAppear {
            // Automatically prompt biometric authentication as soon as the view appears.
            Task { await lockManager.authenticate() }
        }
    }

    // MARK: - Helpers

    private var biometricIcon: String {
        switch lockManager.biometricType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        @unknown default: return "lock"
        }
    }
}

// MARK: - View Extension

extension View {
    /// Wraps a view with the `AppLockView` overlay when the app is locked.
    func withAppLock(_ lockManager: AppLockManager = .shared) -> some View {
        self.modifier(AppLockOverlayModifier(lockManager: lockManager))
    }
}

// MARK: - AppLockOverlayModifier

private struct AppLockOverlayModifier: ViewModifier {
    @ObservedObject var lockManager: AppLockManager

    func body(content: Content) -> some View {
        ZStack {
            content
            if lockManager.isLocked {
                AppLockView(lockManager: lockManager)
                    .transition(.opacity)
                    .zIndex(1000)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: lockManager.isLocked)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Locked") {
    let manager = AppLockManager.shared
    manager.isLocked = true
    return AppLockView(lockManager: manager)
}
#endif
