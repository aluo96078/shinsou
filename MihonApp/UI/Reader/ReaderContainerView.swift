import SwiftUI
import UIKit
import MihonUI

// MARK: - ReaderDestination

/// Identifiable wrapper so we can use `fullScreenCover(item:)`.
struct ReaderDestination: Identifiable {
    let mangaId: Int64
    let chapterId: Int64
    var id: Int64 { chapterId }
}

// MARK: - ColorFilterOverlayView (SwiftUI bridge for ColorFilterOverlay)

private struct ColorFilterOverlayView: UIViewRepresentable {
    let filterType: ColorFilterType
    let brightness: CGFloat

    func makeUIView(context: Context) -> ColorFilterOverlay {
        ColorFilterOverlay()
    }

    func updateUIView(_ uiView: ColorFilterOverlay, context: Context) {
        uiView.filterType = filterType
        uiView.brightness = brightness
    }
}

struct ReaderContainerView: View {
    @StateObject private var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false
    @State private var showChapterList = false

    init(mangaId: Int64, chapterId: Int64) {
        _viewModel = StateObject(wrappedValue: ReaderViewModel(
            mangaId: mangaId,
            chapterId: chapterId,
            mangaRepository: DIContainer.shared.mangaRepository,
            chapterRepository: DIContainer.shared.chapterRepository,
            historyRepository: DIContainer.shared.historyRepository,
            preferences: DIContainer.shared.preferences
        ))
    }

    var body: some View {
        ZStack {
            // Background — always fills entire screen
            Color.black.ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(.white)
            } else if let error = viewModel.error {
                // Error view — scrollable, shows debug logs
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.title2.weight(.medium))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }

                        Spacer()

                        // Open in browser
                        if let chapter = viewModel.chapter, !chapter.url.isEmpty {
                            Button {
                                let urlStr = chapter.url.hasPrefix("http") ? chapter.url : (viewModel.refererUrl ?? "") + chapter.url
                                if let url = URL(string: urlStr) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Image(systemName: "safari")
                                    .font(.title3)
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 44)
                                    .contentShape(Rectangle())
                            }
                        }

                        Button("重試") { Task { await viewModel.loadChapter() } }
                            .buttonStyle(.bordered)
                            .tint(.white)
                    }
                    .padding(.horizontal, 8)

                    ScrollView {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                                .padding(.top, 20)

                            Text(error)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.9))
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .padding(.bottom, 20)
                    }
                }
            } else {
                readerContent
                    .ignoresSafeArea()
            }

            // Color filter overlay
            ColorFilterOverlayView(
                filterType: viewModel.colorFilterType,
                brightness: CGFloat(viewModel.customBrightness)
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Overlay: toolbar and page indicator
            if viewModel.isMenuVisible {
                readerOverlay
            }

            // Page number indicator (only when menu is hidden)
            if viewModel.showPageNumber && !viewModel.isMenuVisible {
                pageIndicator
            }
        }
        .statusBarHidden(!viewModel.isMenuVisible && viewModel.fullscreen)
        .task { await viewModel.loadChapter() }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = viewModel.keepScreenOn
            if viewModel.volumeKeysEnabled {
                viewModel.volumeButtonHandler.start()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            viewModel.volumeButtonHandler.stop()
        }
        .onChange(of: viewModel.volumeKeysEnabled) { enabled in
            if enabled {
                viewModel.volumeButtonHandler.start()
            } else {
                viewModel.volumeButtonHandler.stop()
            }
        }
        .sheet(isPresented: $showSettings) { ReaderSettingsSheet(viewModel: viewModel) }
        .sheet(isPresented: $showChapterList) {
            ReaderChapterListSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var readerContent: some View {
        switch viewModel.readingMode {
        case .pagerLTR:
            PagerReaderView(viewModel: viewModel, direction: .leftToRight)
        case .pagerRTL:
            PagerReaderView(viewModel: viewModel, direction: .rightToLeft)
        case .pagerVertical:
            PagerReaderView(viewModel: viewModel, direction: .vertical)
        case .webtoon, .continuousVertical:
            WebtoonReaderView(viewModel: viewModel)
        }
    }

    // MARK: - Overlay (Mihon-style)

    private var readerOverlay: some View {
        VStack(spacing: 0) {
            // ── Top bar ──
            topBar

            Spacer()

            // ── Bottom bar ──
            bottomBar
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            // Back button
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }

            // Title + chapter
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.manga?.title ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(viewModel.chapter?.name ?? "")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            // Web view button (open chapter URL in browser)
            if let chapter = viewModel.chapter, !chapter.url.isEmpty {
                Button {
                    let urlStr = chapter.url.hasPrefix("http") ? chapter.url : (viewModel.refererUrl ?? "") + chapter.url
                    if let url = URL(string: urlStr) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Image(systemName: "safari")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 44)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.85), .black.opacity(0.5), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            // Page slider row
            if viewModel.totalPages > 0 {
                HStack(spacing: 8) {
                    // Previous chapter
                    Button { Task { await viewModel.moveToPreviousChapter() } } label: {
                        Image(systemName: "backward.end.fill")
                            .font(.caption)
                            .foregroundStyle(viewModel.previousChapterName != nil ? .white : .white.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .disabled(viewModel.previousChapterName == nil)

                    Text("\(viewModel.currentPageIndex + 1)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(minWidth: 24)

                    Slider(
                        value: Binding(
                            get: { Double(viewModel.currentPageIndex) },
                            set: { viewModel.onPageChanged(Int($0)) }
                        ),
                        in: 0...Double(max(viewModel.totalPages - 1, 1)),
                        step: 1
                    )
                    .tint(.white)

                    Text("\(viewModel.totalPages)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(minWidth: 24)

                    // Next chapter
                    Button { Task { await viewModel.moveToNextChapter() } } label: {
                        Image(systemName: "forward.end.fill")
                            .font(.caption)
                            .foregroundStyle(viewModel.nextChapterName != nil ? .white : .white.opacity(0.3))
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .disabled(viewModel.nextChapterName == nil)
                }
                .padding(.horizontal, 8)
                .padding(.top, 12)
            }

            // Action buttons row
            HStack(spacing: 0) {
                // Bookmark
                readerActionButton(
                    icon: viewModel.chapter?.bookmark == true ? "bookmark.fill" : "bookmark",
                    label: "書籤"
                ) {
                    Task { await viewModel.toggleBookmark() }
                }

                // Chapter list
                readerActionButton(icon: "list.bullet", label: "章節") {
                    showChapterList = true
                }

                // Reading mode cycle
                readerActionButton(icon: readingModeIcon, label: readingModeLabel) {
                    viewModel.cycleReadingMode()
                }

                // Settings
                readerActionButton(icon: "gearshape", label: "設定") {
                    showSettings = true
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.5), .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Action Button

    private func readerActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(height: 24)
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reading Mode Helpers

    private var readingModeIcon: String {
        switch viewModel.readingMode {
        case .pagerLTR: return "arrow.left.to.line"
        case .pagerRTL: return "arrow.right.to.line"
        case .pagerVertical: return "arrow.up.and.down"
        case .webtoon: return "arrow.down.to.line"
        case .continuousVertical: return "arrow.up.arrow.down"
        }
    }

    private var readingModeLabel: String {
        switch viewModel.readingMode {
        case .pagerLTR: return "左→右"
        case .pagerRTL: return "右→左"
        case .pagerVertical: return "垂直"
        case .webtoon: return "條漫"
        case .continuousVertical: return "連續"
        }
    }

    // MARK: - Page Indicator (when menu hidden)

    private var pageIndicator: some View {
        VStack {
            Spacer()
            Text("\(viewModel.currentPageIndex + 1) / \(viewModel.totalPages)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6), in: Capsule())
                .padding(.bottom, 16)
        }
    }
}

// MARK: - Reader Chapter List Sheet

struct ReaderChapterListSheet: View {
    @ObservedObject var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.allChaptersSorted, id: \.id) { chapter in
                    Button {
                        Task {
                            await viewModel.switchToChapterById(chapter.id)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chapter.name)
                                    .font(.subheadline)
                                    .foregroundStyle(chapter.read ? .secondary : .primary)
                                    .lineLimit(1)
                                if let scanlator = chapter.scanlator, !scanlator.isEmpty {
                                    Text(scanlator)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            if chapter.id == viewModel.chapter?.id {
                                Image(systemName: "play.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("章節列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
