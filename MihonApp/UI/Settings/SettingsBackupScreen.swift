import SwiftUI

/// Re-exports the existing BackupScreen so the Settings navigation stack
/// can reach it through the standard pattern used by every other sub-screen.
///
/// The real backup UI lives in `MihonApp/UI/Backup/BackupScreen.swift`.
/// This thin wrapper forwards to it and sets the expected navigation title.
struct SettingsBackupScreen: View {
    var body: some View {
        BackupScreen()
    }
}

#Preview {
    NavigationStack {
        SettingsBackupScreen()
    }
}
