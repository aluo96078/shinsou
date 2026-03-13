import Foundation
import LocalAuthentication
import SwiftUI

@MainActor
final class AppLockManager: ObservableObject {

    // MARK: - Shared Instance

    static let shared = AppLockManager()

    // MARK: - Published State

    @Published var isLocked = false
    @Published var isAuthenticating = false

    // MARK: - Persisted Settings

    @AppStorage("settings.security.appLock") var isAppLockEnabled = false
    /// Lock delay in seconds. 0 means lock immediately upon backgrounding.
    @AppStorage("settings.security.lockDelay") var lockDelay = 0
    @AppStorage("settings.security.secureScreen") var secureScreenEnabled = false
    @AppStorage("settings.security.incognitoMode") var incognitoMode = false

    // MARK: - Private State

    private var backgroundTimestamp: Date?

    // MARK: - Init

    private init() {}

    // MARK: - Biometric Info

    /// Returns the biometry type supported by the device.
    var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: nil
        )
        return context.biometryType
    }

    /// Human-readable name of the available biometric method.
    var biometricTypeName: String {
        switch biometricType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        @unknown default: return "Passcode"
        }
    }

    /// Whether any biometric hardware is available (Face ID, Touch ID, or Optic ID).
    var isBiometricAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: nil
        )
    }

    // MARK: - Authentication

    /// Prompts the user to authenticate. Returns `true` on success and clears the lock state.
    @discardableResult
    func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Shinsou"
            )
            if success {
                isLocked = false
            }
            return success
        } catch {
            return false
        }
    }

    // MARK: - App Lifecycle

    /// Call this when the app moves to the background (from `sceneDidEnterBackground` / `applicationDidEnterBackground`).
    func appDidEnterBackground() {
        backgroundTimestamp = Date()

        if secureScreenEnabled {
            NotificationCenter.default.post(
                name: .appShouldApplyPrivacyBlur,
                object: nil
            )
        }
    }

    /// Call this when the app returns to the foreground (from `sceneWillEnterForeground` / `applicationWillEnterForeground`).
    func appWillEnterForeground() {
        NotificationCenter.default.post(
            name: .appShouldRemovePrivacyBlur,
            object: nil
        )

        guard isAppLockEnabled else {
            backgroundTimestamp = nil
            return
        }

        if let timestamp = backgroundTimestamp {
            let elapsed = Date().timeIntervalSince(timestamp)
            if elapsed > Double(lockDelay) {
                isLocked = true
            }
        } else {
            // No timestamp recorded (e.g. first launch with lock enabled).
            isLocked = true
        }

        backgroundTimestamp = nil
    }

    /// Force-lock the app immediately regardless of delay setting.
    func lockNow() {
        guard isAppLockEnabled else { return }
        isLocked = true
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the app should apply the privacy blur overlay (e.g. entering background with secureScreen on).
    static let appShouldApplyPrivacyBlur = Notification.Name("appShouldApplyPrivacyBlur")
    /// Posted when the app should remove the privacy blur overlay.
    static let appShouldRemovePrivacyBlur = Notification.Name("appShouldRemovePrivacyBlur")
}
