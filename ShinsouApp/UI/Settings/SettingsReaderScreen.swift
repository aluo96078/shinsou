import SwiftUI
import ShinsouI18n

// MARK: - Supporting types

extension ReadingMode {
    var displayName: String {
        switch self {
        case .pagerLTR:          return "Left to Right"
        case .pagerRTL:          return "Right to Left"
        case .pagerVertical:     return "Vertical"
        case .webtoon:           return "Webtoon"
        case .continuousVertical: return "Continuous Vertical"
        }
    }
}

enum OrientationLock: Int, CaseIterable, Identifiable {
    case free       = 0
    case portrait   = 1
    case landscape  = 2

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .free:      return "Free Rotation"
        case .portrait:  return "Portrait"
        case .landscape: return "Landscape"
        }
    }
}

// MARK: - View

struct SettingsReaderScreen: View {

    @AppStorage(SettingsKeys.defaultReadingMode)       private var readingModeRaw: Int       = ReadingMode.pagerLTR.rawValue
    @AppStorage(SettingsKeys.defaultOrientationLock)   private var orientationLockRaw: Int   = OrientationLock.free.rawValue
    @AppStorage(SettingsKeys.doubleTapToZoom)          private var doubleTapToZoom: Bool     = true
    @AppStorage(SettingsKeys.showPageNumber)           private var showPageNumber: Bool      = true
    @AppStorage(SettingsKeys.keepScreenOn)             private var keepScreenOn: Bool        = true
    @AppStorage(SettingsKeys.skipFilteredChapters)     private var skipFiltered: Bool        = false
    @AppStorage(SettingsKeys.defaultColorFilter)       private var colorFilterRaw: Int       = ColorFilterType.none.rawValue
    @AppStorage(SettingsKeys.defaultColorFilterBright) private var filterBrightness: Double  = 0.0
    @AppStorage(SettingsKeys.volumeKeys)               private var volumeKeysEnabled: Bool   = false

    private var readingMode: Binding<ReadingMode> {
        Binding(
            get: { ReadingMode(rawValue: readingModeRaw) ?? .pagerLTR },
            set: { readingModeRaw = $0.rawValue }
        )
    }

    private var orientationLock: Binding<OrientationLock> {
        Binding(
            get: { OrientationLock(rawValue: orientationLockRaw) ?? .free },
            set: { orientationLockRaw = $0.rawValue }
        )
    }

    private var colorFilter: Binding<ColorFilterType> {
        Binding(
            get: { ColorFilterType(rawValue: colorFilterRaw) ?? .none },
            set: { colorFilterRaw = $0.rawValue }
        )
    }

    var body: some View {
        List {
            // MARK: Reading Mode
            Section {
                Picker("Default Reading Mode", selection: readingMode) {
                    ForEach(ReadingMode.allCases, id: \.rawValue) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.navigationLink)

                Picker("Default Orientation", selection: orientationLock) {
                    ForEach(OrientationLock.allCases) { lock in
                        Text(lock.displayName).tag(lock)
                    }
                }
                .pickerStyle(.navigationLink)
            } header: {
                Text(MR.strings.readerDefaultMode)
            }

            // MARK: Display
            Section {
                Toggle(isOn: $doubleTapToZoom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.readerDoubleTapZoom)
                        Text(MR.strings.readerDoubleTapZoomDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $showPageNumber) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.readerShowPageNumber)
                        Text(MR.strings.readerShowPageDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $keepScreenOn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.readerKeepScreenOn)
                        Text(MR.strings.readerKeepScreenDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(MR.strings.readerDisplay)
            }

            // MARK: Controls
            Section {
                Toggle(isOn: Binding(
                    get: { volumeKeysEnabled },
                    set: { newValue in
                        volumeKeysEnabled = newValue
                        // 立即安裝或移除 HUD 抑制
                        if newValue {
                            VolumeButtonHandler.shared.installHUDSuppression()
                        } else {
                            VolumeButtonHandler.shared.removeHUDSuppression()
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.readerVolumeKeys)
                        Text(MR.strings.readerVolumeKeysDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(MR.strings.readerControls)
            }

            // MARK: Chapters
            Section {
                Toggle(isOn: $skipFiltered) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.readerSkipFiltered)
                        Text(MR.strings.readerSkipFilteredDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(MR.strings.readerChaptersSection)
            }

            // MARK: Color Filter
            Section {
                Picker("Default Color Filter", selection: colorFilter) {
                    ForEach(ColorFilterType.allCases, id: \.rawValue) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.navigationLink)

                if colorFilter.wrappedValue == .customBrightness {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(MR.strings.readerBrightnessOffset)
                            Spacer()
                            Text(String(format: "%+.0f%%", filterBrightness * 100))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $filterBrightness, in: -0.5...0.5, step: 0.01)
                    }
                }
            } header: {
                Text(MR.strings.readerColorFilterDefaults)
            } footer: {
                Text(MR.strings.readerColorFilterDefaultsDesc)
            }
        }
        .navigationTitle(MR.strings.settingsReader)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsReaderScreen()
    }
}
