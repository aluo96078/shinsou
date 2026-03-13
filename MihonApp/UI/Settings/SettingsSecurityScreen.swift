import SwiftUI
import LocalAuthentication
import MihonI18n

// MARK: - Supporting types

enum LockDelay: Int, CaseIterable, Identifiable {
    case immediately   = 0
    case after10Sec    = 10
    case after30Sec    = 30
    case after1Min     = 60
    case after5Min     = 300
    case after10Min    = 600

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .immediately:  return MR.strings.securityLockImmediately
        case .after10Sec:   return MR.strings.securityLock10s
        case .after30Sec:   return MR.strings.securityLock30s
        case .after1Min:    return MR.strings.securityLock1m
        case .after5Min:    return MR.strings.securityLock5m
        case .after10Min:   return MR.strings.securityLock10m
        }
    }
}

// MARK: - View

struct SettingsSecurityScreen: View {

    @AppStorage(SettingsKeys.appLockEnabled)    private var appLockEnabled: Bool    = false
    @AppStorage(SettingsKeys.lockAfterDelay)    private var lockDelayRaw: Int       = LockDelay.immediately.rawValue
    @AppStorage(SettingsKeys.secureScreen)      private var secureScreen: Bool      = false
    @AppStorage(SettingsKeys.incognitoMode)     private var incognitoMode: Bool     = false

    @State private var biometricsAvailable = false
    @State private var biometryType: LABiometryType = .none
    @State private var showLockUnavailableAlert = false

    private var lockDelay: Binding<LockDelay> {
        Binding(
            get: { LockDelay(rawValue: lockDelayRaw) ?? .immediately },
            set: { lockDelayRaw = $0.rawValue }
        )
    }

    var body: some View {
        List {
            // MARK: App Lock
            Section {
                Toggle(isOn: appLockEnabledBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.securityRequireAuth)
                        Text(biometryDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if appLockEnabled {
                    Picker("Lock After", selection: lockDelay) {
                        ForEach(LockDelay.allCases) { delay in
                            Text(delay.displayName).tag(delay)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
            } header: {
                Text(MR.strings.securityAppLock)
            } footer: {
                Text(MR.strings.securityAppLockFooter)
            }

            // MARK: Privacy
            Section {
                Toggle(isOn: $secureScreen) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.securitySecureScreen)
                        Text(MR.strings.securitySecureScreenDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $incognitoMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.securityIncognito)
                        Text(MR.strings.securityIncognitoDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(MR.strings.securityPrivacy)
            }
        }
        .navigationTitle(MR.strings.securityTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { checkBiometrics() }
        .alert(MR.strings.securityAuthUnavailable, isPresented: $showLockUnavailableAlert) {
            Button(MR.strings.commonOk, role: .cancel) {}
        } message: {
            Text(MR.strings.securityAuthUnavailableMsg)
        }
    }

    // MARK: - Helpers

    /// Intercept the toggle so we can verify biometrics are available first.
    private var appLockEnabledBinding: Binding<Bool> {
        Binding(
            get: { appLockEnabled },
            set: { newValue in
                if newValue && !biometricsAvailable {
                    showLockUnavailableAlert = true
                } else {
                    appLockEnabled = newValue
                }
            }
        )
    }

    private var biometryDescription: String {
        switch biometryType {
        case .faceID:    return "Protect the app with Face ID."
        case .touchID:   return "Protect the app with Touch ID."
        case .opticID:   return "Protect the app with Optic ID."
        @unknown default: return "Protect the app with device authentication."
        }
    }

    private func checkBiometrics() {
        let context = LAContext()
        var error: NSError?
        biometricsAvailable = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        biometryType = context.biometryType
    }
}

#Preview {
    NavigationStack {
        SettingsSecurityScreen()
    }
}
