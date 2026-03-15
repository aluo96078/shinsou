import SwiftUI
import ShinsouI18n

// MARK: - Tracker row

private struct TrackerRowView: View {
    let tracker: any Tracker
    @State private var showLogin = false
    @State private var showLogoutConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            // Logo placeholder — real implementation would use an Image asset
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(tracker.name)
                    .font(.body)
                Text(tracker.isLoggedIn ? MR.strings.trackConnected : MR.strings.trackNotConnected)
                    .font(.caption)
                    .foregroundStyle(tracker.isLoggedIn ? .green : .secondary)
            }

            Spacer()

            if tracker.isLoggedIn {
                Button(MR.strings.trackLogoutButton) {
                    showLogoutConfirmation = true
                }
                .font(.subheadline)
                .foregroundStyle(.red)
                .buttonStyle(.borderless)
            } else {
                Button(MR.strings.trackLoginButton) {
                    showLogin = true
                }
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showLogin) {
            TrackerLoginSheet(tracker: IdentifiableTracker(tracker: tracker), onLoginSuccess: { })
        }
        .confirmationDialog(
            "Log out of \(tracker.name)?",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button(MR.strings.trackLogoutButton, role: .destructive) {
                tracker.logout()
            }
            Button(MR.strings.commonCancel, role: .cancel) {}
        } message: {
            Text(MR.strings.trackLogoutDesc(tracker.name))
        }
    }
}

// MARK: - Main view

struct SettingsTrackingScreen: View {

    @ObservedObject private var trackerManager = TrackerManager.shared

    @AppStorage(SettingsKeys.autoSyncAfterRead)      private var autoSync: Bool         = true
    @AppStorage(SettingsKeys.updateProgressAfterRead) private var updateProgress: Bool  = true

    var body: some View {
        List {
            // MARK: Services
            Section {
                ForEach(trackerManager.trackers, id: \.id) { tracker in
                    TrackerRowView(tracker: tracker)
                }
            } header: {
                Text(MR.strings.trackServices)
            } footer: {
                Text(MR.strings.trackServicesFooter)
            }

            // MARK: Sync behaviour
            Section {
                Toggle(isOn: $autoSync) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.trackAutoSync)
                        Text(MR.strings.trackAutoSyncDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $updateProgress) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.trackUpdateProgress)
                        Text(MR.strings.trackUpdateProgressDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!autoSync)
            } header: {
                Text(MR.strings.trackSyncBehaviour)
            }
        }
        .navigationTitle(MR.strings.trackTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsTrackingScreen()
    }
}
