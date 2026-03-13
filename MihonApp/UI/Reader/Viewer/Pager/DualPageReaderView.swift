import SwiftUI
import UIKit
import MihonSourceAPI

/// iPad 橫向雙頁閱讀模式
///
/// 頁面配對規則（標準漫畫慣例）：
/// - 第一頁（封面）單獨顯示
/// - 其後每兩頁並排顯示
/// - 若總頁數為偶數，最後一頁單獨顯示
/// - RTL 模式下右頁在前（日式漫畫）、LTR 模式左頁在前
struct DualPageReaderView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: ReaderViewModel
    let isRTL: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [.interPageSpacing: 0]
        )
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        pvc.view.backgroundColor = .black

        // 設定初始雙頁
        if !viewModel.pages.isEmpty {
            let pairIndex = pairIndexForPage(viewModel.currentPageIndex)
            let initial = makeDualPageVC(at: pairIndex, coordinator: context.coordinator)
            pvc.setViewControllers([initial], direction: .forward, animated: false)
        }

        return pvc
    }

    func updateUIViewController(_ uvc: UIPageViewController, context: Context) {
        // 當頁面首次載入時設定初始畫面
        if !viewModel.pages.isEmpty && uvc.viewControllers?.isEmpty != false {
            let pairIndex = pairIndexForPage(viewModel.currentPageIndex)
            let vc = makeDualPageVC(at: pairIndex, coordinator: context.coordinator)
            uvc.setViewControllers([vc], direction: .forward, animated: false)
        }
    }

    // MARK: - 頁面配對計算

    /// 計算所有頁面的雙頁配對組合
    var pagePairs: [(leftIndex: Int, rightIndex: Int?)] {
        var pairs: [(leftIndex: Int, rightIndex: Int?)] = []
        let totalPages = viewModel.pages.count
        guard totalPages > 0 else { return pairs }

        // 第一頁（封面）單獨顯示
        pairs.append((leftIndex: 0, rightIndex: nil))

        var i = 1
        while i < totalPages {
            if i + 1 < totalPages {
                // 兩頁並排
                pairs.append((leftIndex: i, rightIndex: i + 1))
                i += 2
            } else {
                // 最後一頁單獨顯示
                pairs.append((leftIndex: i, rightIndex: nil))
                i += 1
            }
        }

        return pairs
    }

    /// 根據頁面索引找到對應的配對索引
    func pairIndexForPage(_ pageIndex: Int) -> Int {
        for (pairIdx, pair) in pagePairs.enumerated() {
            if pair.leftIndex == pageIndex || pair.rightIndex == pageIndex {
                return pairIdx
            }
        }
        return 0
    }

    /// 建立雙頁顯示的 ViewController
    func makeDualPageVC(at pairIndex: Int, coordinator: Coordinator) -> DualPageViewController {
        let pairs = pagePairs
        guard pairIndex >= 0 && pairIndex < pairs.count else {
            return DualPageViewController()
        }

        let pair = pairs[pairIndex]
        guard pair.leftIndex < viewModel.pages.count else {
            return DualPageViewController()
        }
        let leftPage = viewModel.pages[pair.leftIndex]
        let rightPage = pair.rightIndex.flatMap { $0 < viewModel.pages.count ? viewModel.pages[$0] : nil }

        let vc = DualPageViewController()
        vc.pairIndex = pairIndex
        vc.leftPageIndex = pair.leftIndex
        vc.rightPageIndex = pair.rightIndex
        vc.leftPage = leftPage
        vc.rightPage = rightPage
        vc.isRTL = isRTL
        vc.onTap = { [weak viewModel] in viewModel?.toggleMenu() }
        return vc
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        let parent: DualPageReaderView

        init(_ parent: DualPageReaderView) {
            self.parent = parent
        }

        // 前一個配對（RTL 時為下一組頁碼，LTR 時為上一組）
        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let vc = viewController as? DualPageViewController,
                  let currentPairIndex = vc.pairIndex else { return nil }

            let prevPairIndex = parent.isRTL ? currentPairIndex + 1 : currentPairIndex - 1
            guard prevPairIndex >= 0 && prevPairIndex < parent.pagePairs.count else { return nil }
            return parent.makeDualPageVC(at: prevPairIndex, coordinator: self)
        }

        // 後一個配對
        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let vc = viewController as? DualPageViewController,
                  let currentPairIndex = vc.pairIndex else { return nil }

            let nextPairIndex = parent.isRTL ? currentPairIndex - 1 : currentPairIndex + 1
            guard nextPairIndex >= 0 && nextPairIndex < parent.pagePairs.count else { return nil }
            return parent.makeDualPageVC(at: nextPairIndex, coordinator: self)
        }

        // 翻頁完成後更新目前頁碼
        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  let vc = pageViewController.viewControllers?.first as? DualPageViewController,
                  let leftIndex = vc.leftPageIndex else { return }

            Task { @MainActor in
                parent.viewModel.onPageChanged(leftIndex)
            }
        }
    }
}

// MARK: - DualPageViewController

/// 顯示一組雙頁（或單頁）的 UIViewController
final class DualPageViewController: UIViewController {
    var pairIndex: Int?
    var leftPageIndex: Int?
    var rightPageIndex: Int?
    var leftPage: Page?
    var rightPage: Page?
    var isRTL: Bool = false
    var onTap: (() -> Void)?

    private let containerStack = UIStackView()
    private var leftPageVC: ReaderPageViewController?
    private var rightPageVC: ReaderPageViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupLayout()
        loadPages()
        setupGestures()
    }

    // MARK: - 佈局設置

    private func setupLayout() {
        containerStack.axis = .horizontal
        containerStack.distribution = .fillEqually
        containerStack.spacing = 0
        containerStack.backgroundColor = .black
        containerStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(containerStack)
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: view.topAnchor),
            containerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - 頁面載入

    private func loadPages() {
        // RTL（日式右翻）：右頁在前，左頁在後
        // LTR（美式左翻）：左頁在前，右頁在後
        let firstPage: Page?
        let secondPage: Page?

        if isRTL {
            // 右側顯示較小頁碼（先讀）
            firstPage = rightPage ?? leftPage
            secondPage = rightPage != nil ? leftPage : nil
        } else {
            firstPage = leftPage
            secondPage = rightPage
        }

        // 加入第一頁
        if let page = firstPage {
            let vc = makePageVC(page: page)
            addPageVC(vc)
            leftPageVC = vc
        }

        // 加入第二頁（雙頁模式）
        if let page = secondPage {
            let vc = makePageVC(page: page)
            addPageVC(vc)
            rightPageVC = vc
        }
    }

    private func makePageVC(page: Page) -> ReaderPageViewController {
        let vc = ReaderPageViewController()
        vc.page = page
        vc.onTapCenter = { [weak self] in self?.onTap?() }
        return vc
    }

    private func addPageVC(_ vc: UIViewController) {
        addChild(vc)
        containerStack.addArrangedSubview(vc.view)
        vc.didMove(toParent: self)
    }

    // MARK: - 手勢

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.numberOfTapsRequired = 1
        // 只在容器層捕捉，不攔截子頁面的縮放手勢
        view.addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        onTap?()
    }
}
