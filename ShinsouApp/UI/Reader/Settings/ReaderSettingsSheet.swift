import SwiftUI
import ShinsouDomain
import ShinsouI18n

struct ReaderSettingsSheet: View {
    @ObservedObject var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(MR.strings.readerReadingMode) {
                    Picker(MR.strings.readerMode, selection: $viewModel.readingMode) {
                        ForEach(ReadingMode.allCases, id: \.rawValue) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                Section(MR.strings.readerDisplay) {
                    Toggle(MR.strings.readerShowPageNumber, isOn: $viewModel.showPageNumber)
                    Toggle(MR.strings.readerKeepScreenOn, isOn: $viewModel.keepScreenOn)
                    Toggle(MR.strings.readerFullscreen, isOn: $viewModel.fullscreen)
                }

                Section(MR.strings.readerControls) {
                    Toggle(MR.strings.readerVolumeKeys, isOn: Binding(
                        get: { viewModel.volumeKeysEnabled },
                        set: { newValue in
                            viewModel.volumeKeysEnabled = newValue
                            UserDefaults.standard.set(newValue, forKey: SettingsKeys.volumeKeys)
                            if newValue {
                                VolumeButtonHandler.shared.installHUDSuppression()
                            } else {
                                VolumeButtonHandler.shared.removeHUDSuppression()
                            }
                        }
                    ))
                }

                Section(MR.strings.readerColorFilter) {
                    Picker(MR.strings.readerColorFilter, selection: Binding(
                        get: { viewModel.colorFilterType },
                        set: { viewModel.colorFilterType = $0 }
                    )) {
                        ForEach(ColorFilterType.allCases, id: \.rawValue) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }

                    if viewModel.colorFilterType == .customBrightness {
                        HStack {
                            Text(MR.strings.readerBrightness)
                            Slider(value: Binding(
                                get: { Double(viewModel.customBrightness) },
                                set: { viewModel.customBrightness = Float($0) }
                            ), in: -0.5...0.5)
                        }
                    }
                }

                // MARK: Image Processing

                Section {
                    Toggle(
                        isOn: Binding(
                            get: { viewModel.splitTallImages },
                            set: {
                                viewModel.splitTallImages = $0
                                UserDefaults.standard.set($0, forKey: SettingsKeys.splitTallImages)
                            }
                        )
                    ) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(MR.strings.readerSplitTall)
                            Text(MR.strings.readerSplitTallDesc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(MR.strings.readerImageProcessing)
                }

                // MARK: Webtoon

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(MR.strings.readerSidePadding)
                            Spacer()
                            Text("\(Int(viewModel.webtoonSidePadding))%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(
                            value: Binding(
                                get: { viewModel.webtoonSidePadding },
                                set: {
                                    viewModel.webtoonSidePadding = $0
                                    UserDefaults.standard.set($0, forKey: SettingsKeys.webtoonSidePadding)
                                }
                            ),
                            in: 0...25,
                            step: 1
                        )
                        .labelsHidden()
                    }
                } header: {
                    Text(MR.strings.readerWebtoon)
                } footer: {
                    Text(MR.strings.readerWebtoonFooter)
                }
            }
            .navigationTitle(MR.strings.readerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(MR.strings.commonDone) { dismiss() }
                }
            }
        }
    }
}
