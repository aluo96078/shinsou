import SwiftUI
import ShinsouI18n

// MARK: - MoreScreen

struct MoreScreen: View {

    @AppStorage(SettingsKeys.incognitoMode) private var isIncognito = false
    @AppStorage(SettingsKeys.downloadOnly)  private var isDownloadOnly = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: Active Mode Banner(s)
                if isIncognito || isDownloadOnly {
                    activeModesBanner
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                // MARK: Privacy / Download Modes
                Section {
                    Toggle(isOn: $isIncognito) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(MR.strings.moreIncognitoMode)
                                Text(MR.strings.moreIncognitoDesc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "eye.slash")
                                .foregroundStyle(isIncognito ? .purple : .secondary)
                        }
                    }
                    .tint(.purple)

                    Toggle(isOn: $isDownloadOnly) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(MR.strings.moreDownloadOnly)
                                Text(MR.strings.moreDownloadOnlyDesc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(isDownloadOnly ? .orange : .secondary)
                        }
                    }
                    .tint(.orange)
                }

                // MARK: Content
                Section {
                    NavigationLink {
                        DownloadQueueScreen()
                    } label: {
                        Label(MR.strings.moreDownloadQueue, systemImage: "arrow.down.circle")
                    }

                    NavigationLink {
                        StatisticsScreen()
                    } label: {
                        Label(MR.strings.moreStatistics, systemImage: "chart.bar")
                    }

                } header: {
                    Text(MR.strings.moreSectionContent)
                }

                // MARK: App
                Section {
                    NavigationLink {
                        SettingsScreen()
                    } label: {
                        Label(MR.strings.settingsTitle, systemImage: "gear")
                    }

                    NavigationLink {
                        AboutScreen()
                    } label: {
                        Label(MR.strings.settingsAbout, systemImage: "info.circle")
                    }
                } header: {
                    Text(MR.strings.moreSectionApp)
                }
            }
            .navigationTitle(MR.strings.moreTitle)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Active Modes Banner

    @ViewBuilder
    private var activeModesBanner: some View {
        VStack(spacing: 6) {
            if isIncognito {
                ModeBannerRow(
                    icon: "eye.slash.fill",
                    label: MR.strings.moreIncognitoActive,
                    color: .purple
                )
            }
            if isDownloadOnly {
                ModeBannerRow(
                    icon: "arrow.down.circle.fill",
                    label: MR.strings.moreDownloadOnlyActive,
                    color: .orange
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

// MARK: - ModeBannerRow

private struct ModeBannerRow: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    MoreScreen()
}
