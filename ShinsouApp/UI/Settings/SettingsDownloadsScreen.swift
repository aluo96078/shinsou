import SwiftUI
import ShinsouI18n

struct SettingsDownloadsScreen: View {

    @AppStorage(SettingsKeys.downloadLocation)        private var downloadLocation: String    = "Default"
    @AppStorage(SettingsKeys.autoDownloadNewChapters) private var autoDownload: Bool          = false
    @AppStorage(SettingsKeys.deleteAfterReading)      private var deleteAfterReading: Bool    = false
    @AppStorage(SettingsKeys.downloadOnWifiOnly)      private var wifiOnly: Bool              = true
    @AppStorage(SettingsKeys.parallelDownloads)       private var parallelDownloads: Int      = 3
    @AppStorage(SettingsKeys.removeAfterMarkedRead)   private var removeAfterMarkedRead: Bool = false

    @State private var showLocationPicker = false

    private let parallelOptions = [1, 2, 3, 5, 10]

    var body: some View {
        List {
            // MARK: Storage
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.downloadsLocation)
                        Text(resolvedLocationLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(MR.strings.commonChange) {
                        showLocationPicker = true
                    }
                    .foregroundStyle(Color.accentColor)
                }
            } header: {
                Text(MR.strings.downloadsStorage)
            } footer: {
                Text(MR.strings.downloadsLocationFooter)
            }

            // MARK: Automation
            Section {
                Toggle(isOn: $autoDownload) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.downloadsAutoDownload)
                        Text(MR.strings.downloadsAutoDownloadDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $deleteAfterReading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.downloadsDeleteAfterRead)
                        Text(MR.strings.downloadsDeleteAfterReadDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $removeAfterMarkedRead) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.downloadsRemoveAfterMarked)
                        Text(MR.strings.downloadsRemoveAfterMarkedDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!deleteAfterReading)
            } header: {
                Text(MR.strings.downloadsAutomation)
            }

            // MARK: Network
            Section {
                Toggle(isOn: $wifiOnly) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.downloadsWifiOnly)
                        Text(MR.strings.downloadsWifiOnlyDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(MR.strings.downloadsNetwork)
            }

            // MARK: Performance
            Section {
                Picker(MR.strings.downloadsParallel, selection: $parallelDownloads) {
                    ForEach(parallelOptions, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text(MR.strings.downloadsPerformance)
            } footer: {
                Text(MR.strings.downloadsPerformanceFooter)
            }
        }
        .navigationTitle(MR.strings.downloadsTitle)
        .navigationBarTitleDisplayMode(.inline)
        // A real implementation would present a document picker here.
        .alert(MR.strings.downloadsLocation, isPresented: $showLocationPicker) {
            Button(MR.strings.downloadsDefaultLocation) { downloadLocation = "Default" }
            Button(MR.strings.commonCancel, role: .cancel) {}
        } message: {
            Text(MR.strings.downloadsCustomFolderNote)
        }
    }

    private var resolvedLocationLabel: String {
        downloadLocation == "Default" ? "App Documents / Downloads" : downloadLocation
    }
}

#Preview {
    NavigationStack {
        SettingsDownloadsScreen()
    }
}
