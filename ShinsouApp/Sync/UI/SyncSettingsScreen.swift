import SwiftUI
import ShinsouI18n

struct SyncSettingsScreen: View {

    @ObservedObject private var syncManager = SyncManager.shared
    @State private var showRestoreAlert = false
    @State private var restoreURL: URL?
    @State private var showResetAlert = false
    @State private var showCloudKitUnavailableAlert = false
    @State private var isRestoring = false

    private var dateFormatter: DateFormatter {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }

    var body: some View {
        List {
            // MARK: - iCloud 狀態
            Section {
                HStack {
                    Text(MR.strings.syncICloudStatus)
                    Spacer()
                    Text(accountStatusText)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - iCloud Drive 備份同步
            Section {
                Toggle(isOn: Binding(
                    get: { syncManager.isICloudDriveBackupEnabled },
                    set: { newValue in
                        syncManager.isICloudDriveBackupEnabled = newValue
                        if newValue {
                            ICloudDriveMonitor.shared.startMonitoring()
                        } else {
                            ICloudDriveMonitor.shared.stopMonitoring()
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.syncAutoBackup)
                        Text(MR.strings.syncAutoBackupDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    Task { await syncManager.uploadLatestBackupToICloud() }
                } label: {
                    HStack {
                        Text(MR.strings.syncBackupNow)
                        Spacer()
                        if syncManager.iCloudDriveStatus.isActive {
                            ProgressView()
                        }
                    }
                }
                .disabled(syncManager.iCloudDriveStatus.isActive)

                if let lastDate = syncManager.lastICloudBackupDate {
                    HStack {
                        Text(MR.strings.syncLastSync)
                        Spacer()
                        Text(dateFormatter.string(from: lastDate))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(MR.strings.syncICloudDriveSection)
            }

            // MARK: - 雲端備份列表
            Section {
                if syncManager.cloudBackups.isEmpty {
                    Text(MR.strings.syncNoCloudBackups)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(syncManager.cloudBackups, id: \.absoluteString) { url in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                if let date = fileDate(url) {
                                    Text(dateFormatter.string(from: date))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button(MR.strings.syncRestoreFrom) {
                                restoreURL = url
                                showRestoreAlert = true
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.blue)
                        }
                    }
                }
            } header: {
                Text(MR.strings.syncCloudBackups)
            }

            // MARK: - CloudKit 即時同步
            Section {
                Toggle(isOn: Binding(
                    get: { syncManager.isCloudKitSyncEnabled },
                    set: { newValue in
                        if newValue && !CloudKitZoneManager.shared.isAvailable {
                            showCloudKitUnavailableAlert = true
                            return
                        }
                        syncManager.isCloudKitSyncEnabled = newValue
                        if newValue {
                            DIContainer.shared.enableSyncObserver()
                            Task { await syncManager.performCloudKitSync() }
                        } else {
                            DIContainer.shared.disableSyncObserver()
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.syncCloudKitEnabled)
                        Text(MR.strings.syncCloudKitEnabledDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if syncManager.isCloudKitSyncEnabled {
                    HStack {
                        Text(cloudKitStatusText)
                            .foregroundStyle(cloudKitStatusColor)
                        Spacer()
                        if let lastDate = syncManager.lastCloudKitSyncDate {
                            Text(dateFormatter.string(from: lastDate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        Task { await syncManager.performCloudKitSync() }
                    } label: {
                        HStack {
                            Text(MR.strings.syncSyncNow)
                            Spacer()
                            if syncManager.cloudKitStatus.isActive {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(syncManager.cloudKitStatus.isActive)

                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Text(MR.strings.syncResetCloud)
                    }
                }
            } header: {
                Text(MR.strings.syncCloudKitSection)
            }
        }
        .navigationTitle(MR.strings.syncTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncManager.refreshCloudBackups()
            Task { await syncManager.checkICloudAccount() }
        }
        .alert(MR.strings.syncRestoreConfirm, isPresented: $showRestoreAlert) {
            Button(MR.strings.syncRestore) {
                guard let url = restoreURL else { return }
                Task { await restoreBackup(from: url) }
            }
            Button(MR.strings.commonCancel, role: .cancel) {}
        } message: {
            Text(MR.strings.syncRestoreConfirmMsg)
        }
        .alert(MR.strings.syncResetCloudConfirm, isPresented: $showResetAlert) {
            Button(MR.strings.syncResetCloud, role: .destructive) {
                Task { try? await syncManager.resetCloudKitData() }
            }
            Button(MR.strings.commonCancel, role: .cancel) {}
        } message: {
            Text(MR.strings.syncResetCloudConfirmMsg)
        }
        .alert(MR.strings.syncCloudKitUnavailableTitle, isPresented: $showCloudKitUnavailableAlert) {
            Button(MR.strings.commonOk, role: .cancel) {}
        } message: {
            Text(MR.strings.syncCloudKitUnavailableMsg)
        }
        .overlay {
            if isRestoring {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
            }
        }
    }

    // MARK: - Helpers

    private var accountStatusText: String {
        switch syncManager.iCloudAccountStatus {
        case .available: return MR.strings.syncAccountAvailable
        case .noAccount: return MR.strings.syncAccountNoAccount
        case .restricted: return MR.strings.syncAccountRestricted
        default: return MR.strings.syncAccountUnknown
        }
    }

    private var cloudKitStatusText: String {
        switch syncManager.cloudKitStatus {
        case .idle: return MR.strings.syncStatusIdle
        case .syncing: return MR.strings.syncStatusSyncing
        case .success: return MR.strings.syncStatusSuccess
        case .error(let msg): return "\(MR.strings.syncStatusError): \(msg)"
        }
    }

    private var cloudKitStatusColor: Color {
        switch syncManager.cloudKitStatus {
        case .idle: return .secondary
        case .syncing: return .blue
        case .success: return .green
        case .error: return .red
        }
    }

    private func fileDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func restoreBackup(from cloudURL: URL) async {
        isRestoring = true
        do {
            let localURL = try await syncManager.restoreFromCloud(cloudURL: cloudURL)
            let restorer = BackupRestorer()
            _ = try await restorer.restoreBackup(from: localURL, options: BackupRestoreOptions())
        } catch {
            print("[SyncSettings] 還原失敗：\(error)")
        }
        isRestoring = false
    }
}
