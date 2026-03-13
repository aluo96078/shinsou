import SwiftUI

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
                Text("Default Mode")
            }

            // MARK: Display
            Section {
                Toggle(isOn: $doubleTapToZoom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Double-Tap to Zoom")
                        Text("Double-tap on a page to zoom in or reset the zoom level.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $showPageNumber) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Page Number")
                        Text("Display the current page number at the bottom of the screen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $keepScreenOn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keep Screen On")
                        Text("Prevent the display from dimming while reading.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Display")
            }

            // MARK: Chapters
            Section {
                Toggle(isOn: $skipFiltered) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Skip Filtered Chapters")
                        Text("Automatically skip chapters that are hidden by your active filters.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Chapters")
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
                            Text("Brightness Offset")
                            Spacer()
                            Text(String(format: "%+.0f%%", filterBrightness * 100))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $filterBrightness, in: -0.5...0.5, step: 0.01)
                    }
                }
            } header: {
                Text("Color Filter Defaults")
            } footer: {
                Text("These defaults are applied when opening a chapter for the first time. They can be overridden per-session in the reader settings.")
            }
        }
        .navigationTitle("Reader")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsReaderScreen()
    }
}
