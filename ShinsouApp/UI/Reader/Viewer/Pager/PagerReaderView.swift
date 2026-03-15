import SwiftUI
import UIKit
import ShinsouSourceAPI

enum PagerDirection {
    case leftToRight
    case rightToLeft
    case vertical
}

// MARK: - PagerItem

/// Represents either a manga page or a chapter-transition screen in the pager.
enum PagerItem {
    case page(index: Int)
    case transition(ChapterTransitionInfo)
}

struct PagerReaderView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: ReaderViewModel
    let direction: PagerDirection

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let orientation: UIPageViewController.NavigationOrientation =
            direction == .vertical ? .vertical : .horizontal

        let pvc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: orientation,
            options: [.interPageSpacing: 0]
        )
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        pvc.view.backgroundColor = .black

        context.coordinator.pageViewController = pvc

        let items = context.coordinator.buildItems()
        context.coordinator.items = items
        if !items.isEmpty {
            let startIndex = context.coordinator.pagerIndex(forPageIndex: viewModel.currentPageIndex)
            context.coordinator.currentPagerIndex = startIndex
            context.coordinator.lastSyncedPageIndex = viewModel.currentPageIndex
            let initial = makeItemVC(items[startIndex], pagerIndex: startIndex, coordinator: context.coordinator)
            pvc.setViewControllers([initial], direction: .forward, animated: false)
        }

        return pvc
    }

    func updateUIViewController(_ uvc: UIPageViewController, context: Context) {
        let newItems = context.coordinator.buildItems()
        let coordinator = context.coordinator

        // Rebuild when page count changes (chapter loaded / changed)
        if newItems.count != coordinator.items.count {
            coordinator.items = newItems
            if !newItems.isEmpty {
                let startIndex = coordinator.pagerIndex(forPageIndex: viewModel.currentPageIndex)
                coordinator.currentPagerIndex = startIndex
                coordinator.lastSyncedPageIndex = viewModel.currentPageIndex
                let vc = makeItemVC(newItems[startIndex], pagerIndex: startIndex, coordinator: coordinator)
                uvc.setViewControllers([vc], direction: .forward, animated: false)
            }
            return
        }

        // Only navigate when the viewModel's page index was changed externally (e.g. slider),
        // NOT when we already synced via swipe/tap (lastSyncedPageIndex tracks this).
        let vmPage = viewModel.currentPageIndex
        if vmPage != coordinator.lastSyncedPageIndex && !coordinator.items.isEmpty {
            let targetPagerIndex = coordinator.pagerIndex(forPageIndex: vmPage)
            let animDirection: UIPageViewController.NavigationDirection =
                targetPagerIndex > coordinator.currentPagerIndex ? .forward : .reverse
            coordinator.currentPagerIndex = targetPagerIndex
            coordinator.lastSyncedPageIndex = vmPage
            let vc = makeItemVC(coordinator.items[targetPagerIndex], pagerIndex: targetPagerIndex, coordinator: coordinator)
            uvc.setViewControllers([vc], direction: animDirection, animated: false)
        }
    }

    // MARK: - VC factory

    func makeItemVC(_ item: PagerItem, pagerIndex: Int? = nil, coordinator: Coordinator) -> UIViewController {
        switch item {
        case .page(let index):
            return makePageVC(at: index, pagerIndex: pagerIndex, coordinator: coordinator)
        case .transition(let info):
            return makeTransitionVC(info, pagerIndex: pagerIndex, coordinator: coordinator)
        }
    }

    func makePageVC(at index: Int, pagerIndex: Int? = nil, coordinator: Coordinator) -> ReaderPageViewController {
        let vc = ReaderPageViewController()
        guard index >= 0 && index < viewModel.pages.count else {
            vc.pageIndex = index
            return vc
        }
        let page = viewModel.pages[index]
        vc.pageIndex = index
        vc.page = page
        vc.refererUrl = viewModel.refererUrl
        vc.sourceHeaders = viewModel.sourceHeaders
        vc.preResolvedImageUrl = viewModel.resolvedImageUrl(for: index)
        vc.onTapCenter = { [weak viewModel] in viewModel?.toggleMenu() }
        vc.onPageLoaded = { [weak viewModel] idx, resolvedUrl in
            viewModel?.onPageImageLoaded(idx, resolvedUrl: resolvedUrl)
        }

        switch direction {
        case .leftToRight, .vertical:
            vc.onTapLeft = { [weak coordinator] in coordinator?.goToPreviousPage() }
            vc.onTapRight = { [weak coordinator] in coordinator?.goToNextPage() }
        case .rightToLeft:
            vc.onTapLeft = { [weak coordinator] in coordinator?.goToNextPage() }
            vc.onTapRight = { [weak coordinator] in coordinator?.goToPreviousPage() }
        }

        return vc
    }

    private func makeTransitionVC(
        _ info: ChapterTransitionInfo,
        pagerIndex: Int? = nil,
        coordinator: Coordinator? = nil
    ) -> ChapterTransitionViewController {
        let vc = ChapterTransitionViewController()
        vc.transitionInfo = info
        vc.pageIndex = pagerIndex
        vc.onTap = { [weak viewModel] in viewModel?.toggleMenu() }

        // Wire up tap and swipe for chapter navigation
        if let coordinator {
            switch direction {
            case .leftToRight, .vertical:
                vc.onTapLeft = { [weak coordinator] in coordinator?.goToPreviousPage() }
                vc.onTapRight = { [weak coordinator] in coordinator?.goToNextPage() }
                // Swipe left = forward in LTR
                vc.onSwipeLeft = { [weak coordinator] in coordinator?.goToNextPage() }
                vc.onSwipeRight = { [weak coordinator] in coordinator?.goToPreviousPage() }
            case .rightToLeft:
                vc.onTapLeft = { [weak coordinator] in coordinator?.goToNextPage() }
                vc.onTapRight = { [weak coordinator] in coordinator?.goToPreviousPage() }
                // Swipe right = forward in RTL
                vc.onSwipeLeft = { [weak coordinator] in coordinator?.goToPreviousPage() }
                vc.onSwipeRight = { [weak coordinator] in coordinator?.goToNextPage() }
            }
        }

        return vc
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        let parent: PagerReaderView
        var items: [PagerItem] = []
        var currentPagerIndex: Int = 0
        weak var pageViewController: UIPageViewController?

        /// Tracks the last page index we synced to the viewModel, so we can distinguish
        /// slider-driven changes (need navigation) from swipe-driven changes (already navigated).
        var lastSyncedPageIndex: Int = -1

        init(_ parent: PagerReaderView) {
            self.parent = parent
        }

        // MARK: - Programmatic navigation (from tap zones)

        func goToNextPage() {
            guard let pvc = pageViewController else { return }
            guard !items.isEmpty else { return }

            let nextIndex = currentPagerIndex + 1

            if nextIndex >= items.count {
                // Only allow chapter navigation from transition screens
                if case .transition = items[currentPagerIndex] {
                    Task { @MainActor in
                        await parent.viewModel.moveToNextChapter()
                    }
                }
                // On a page item at the end → just navigate to the trailing transition
                // (the DataSource will show it via swipe anyway)
                return
            }

            currentPagerIndex = nextIndex
            let vc = parent.makeItemVC(items[nextIndex], pagerIndex: nextIndex, coordinator: self)
            pvc.setViewControllers([vc], direction: .forward, animated: true)
            syncPageIndex()
        }

        func goToPreviousPage() {
            guard let pvc = pageViewController else { return }
            guard !items.isEmpty else { return }

            let prevIndex = currentPagerIndex - 1

            if prevIndex < 0 {
                // Only allow chapter navigation from transition screens
                if case .transition = items[currentPagerIndex] {
                    Task { @MainActor in
                        await parent.viewModel.moveToPreviousChapter()
                    }
                }
                return
            }

            currentPagerIndex = prevIndex
            let vc = parent.makeItemVC(items[prevIndex], pagerIndex: prevIndex, coordinator: self)
            pvc.setViewControllers([vc], direction: .reverse, animated: true)
            syncPageIndex()
        }

        /// Update viewModel.currentPageIndex if we're on a page item.
        /// Also updates lastSyncedPageIndex so updateUIViewController won't fight us.
        /// Calls onPageChanged synchronously to avoid race with updateUIViewController.
        private func syncPageIndex() {
            guard currentPagerIndex >= 0 && currentPagerIndex < items.count else { return }
            if case .page(let index) = items[currentPagerIndex] {
                lastSyncedPageIndex = index
                // Call onPageChanged directly to update currentPageIndex + save progress.
                // This avoids race conditions where updateUIViewController sees stale values.
                parent.viewModel.onPageChanged(index)
            }
        }

        // MARK: - Build items

        func buildItems() -> [PagerItem] {
            let vm = parent.viewModel
            guard !vm.pages.isEmpty else { return [] }

            var result: [PagerItem] = []

            let leadingTransition = ChapterTransitionInfo(
                currentChapterName: vm.chapter?.name ?? "Current Chapter",
                previousChapterName: vm.previousChapterName,
                nextChapterName: nil
            )
            result.append(.transition(leadingTransition))

            for i in 0..<vm.pages.count {
                result.append(.page(index: i))
            }

            let trailingTransition = ChapterTransitionInfo(
                currentChapterName: vm.chapter?.name ?? "Current Chapter",
                previousChapterName: nil,
                nextChapterName: vm.nextChapterName
            )
            result.append(.transition(trailingTransition))

            return result
        }

        func pagerIndex(forPageIndex pageIndex: Int) -> Int {
            let raw = pageIndex + 1
            return max(0, min(raw, items.count - 1))
        }

        // MARK: UIPageViewControllerDataSource

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let currentIndex = itemIndex(of: viewController) else { return nil }

            let prevIndex: Int
            switch parent.direction {
            case .leftToRight, .vertical:
                prevIndex = currentIndex - 1
            case .rightToLeft:
                prevIndex = currentIndex + 1
            }

            guard prevIndex >= 0 && prevIndex < items.count else { return nil }
            return parent.makeItemVC(items[prevIndex], pagerIndex: prevIndex, coordinator: self)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let currentIndex = itemIndex(of: viewController) else { return nil }

            let nextIndex: Int
            switch parent.direction {
            case .leftToRight, .vertical:
                nextIndex = currentIndex + 1
            case .rightToLeft:
                nextIndex = currentIndex - 1
            }

            guard nextIndex >= 0 && nextIndex < items.count else { return nil }
            return parent.makeItemVC(items[nextIndex], pagerIndex: nextIndex, coordinator: self)
        }

        // MARK: UIPageViewControllerDelegate

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed else { return }

            if let vc = pageViewController.viewControllers?.first as? ReaderPageViewController,
               let index = vc.pageIndex {
                currentPagerIndex = pagerIndex(forPageIndex: index)
                // Update lastSyncedPageIndex BEFORE notifying viewModel,
                // so updateUIViewController won't navigate back.
                lastSyncedPageIndex = index
                parent.viewModel.onPageChanged(index)
            } else if let vc = pageViewController.viewControllers?.first as? ChapterTransitionViewController,
                      let pIdx = vc.pageIndex {
                currentPagerIndex = pIdx
            }
        }

        // MARK: Helpers

        private func itemIndex(of viewController: UIViewController) -> Int? {
            if let vc = viewController as? ReaderPageViewController, let pageIdx = vc.pageIndex {
                let candidate = pageIdx + 1
                guard candidate >= 0 && candidate < items.count else { return nil }
                return candidate
            }
            if let vc = viewController as? ChapterTransitionViewController {
                return vc.pageIndex
            }
            return nil
        }
    }
}
