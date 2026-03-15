import SwiftUI
import ShinsouI18n

// MARK: - ChapterTransitionInfo

struct ChapterTransitionInfo {
    let currentChapterName: String
    let previousChapterName: String?
    let nextChapterName: String?
}

// MARK: - ChapterTransitionView

struct ChapterTransitionView: View {
    let transition: ChapterTransitionInfo

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Finished label
                VStack(alignment: .leading, spacing: 8) {
                    Label(MR.strings.readerFinished, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)

                    Text(transition.currentChapterName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 1)
                    .padding(.horizontal, 32)

                // Next chapter
                VStack(alignment: .leading, spacing: 8) {
                    Label(MR.strings.readerNextChapter, systemImage: "arrow.right.circle")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)

                    if let next = transition.nextChapterName {
                        Text(next)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(MR.strings.readerNoNextChapter)
                            .font(.title3)
                            .fontWeight(.regular)
                            .foregroundStyle(.white.opacity(0.4))
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)

                // Previous chapter
                VStack(alignment: .leading, spacing: 8) {
                    Label(MR.strings.readerPreviousChapter, systemImage: "arrow.left.circle")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)

                    if let previous = transition.previousChapterName {
                        Text(previous)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(MR.strings.readerNoPreviousChapter)
                            .font(.title3)
                            .fontWeight(.regular)
                            .foregroundStyle(.white.opacity(0.4))
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.vertical, 48)
        }
    }
}

// MARK: - ChapterTransitionViewController

/// A UIViewController wrapping ChapterTransitionView, used in UIPageViewController chains.
final class ChapterTransitionViewController: UIViewController {
    var pageIndex: Int?
    var transitionInfo: ChapterTransitionInfo?
    var onTap: (() -> Void)?
    /// Tap/swipe left side of screen (backward direction)
    var onTapLeft: (() -> Void)?
    /// Tap/swipe right side of screen (forward direction)
    var onTapRight: (() -> Void)?
    /// Swipe left → forward in LTR
    var onSwipeLeft: (() -> Void)?
    /// Swipe right → forward in RTL
    var onSwipeRight: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupHostingController()
        setupGestures()
    }

    private func setupHostingController() {
        guard let info = transitionInfo else { return }

        let hostingVC = UIHostingController(rootView: ChapterTransitionView(transition: info))
        hostingVC.view.backgroundColor = .black
        addChild(hostingVC)
        view.addSubview(hostingVC.view)
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingVC.didMove(toParent: self)
    }

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)

        // Swipe gestures for chapter navigation
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        let width = view.bounds.width
        let tapZone = width / 3.0

        if location.x < tapZone {
            onTapLeft?()
        } else if location.x > width - tapZone {
            onTapRight?()
        } else {
            onTap?()
        }
    }

    @objc private func handleSwipeLeft() {
        onSwipeLeft?()
    }

    @objc private func handleSwipeRight() {
        onSwipeRight?()
    }
}

// MARK: - Preview

#Preview {
    ChapterTransitionView(
        transition: ChapterTransitionInfo(
            currentChapterName: "Chapter 42: The Final Battle",
            previousChapterName: "Chapter 41: Prelude",
            nextChapterName: "Chapter 43: Aftermath"
        )
    )
}
