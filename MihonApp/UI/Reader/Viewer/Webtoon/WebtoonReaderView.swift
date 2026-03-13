import SwiftUI
import UIKit
import MihonSourceAPI
import Nuke
import NukeUI

struct WebtoonReaderView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: ReaderViewModel

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> WebtoonViewController {
        let vc = WebtoonViewController()
        vc.coordinator = context.coordinator
        vc.refererUrl = viewModel.refererUrl
        return vc
    }

    func updateUIViewController(_ vc: WebtoonViewController, context: Context) {
        vc.refererUrl = viewModel.refererUrl
        vc.sourceHeaders = viewModel.sourceHeaders
        vc.updatePages(viewModel.pages)
        vc.updateSidePadding(viewModel.webtoonSidePadding)
    }

    class Coordinator {
        let parent: WebtoonReaderView
        init(_ parent: WebtoonReaderView) { self.parent = parent }

        func onPageVisible(_ index: Int) {
            Task { @MainActor in
                parent.viewModel.onPageChanged(index)
            }
        }
        func onTap() {
            Task { @MainActor in
                parent.viewModel.toggleMenu()
            }
        }
        func onPageImageLoaded(_ index: Int, resolvedUrl: String?) {
            Task { @MainActor in
                parent.viewModel.onPageImageLoaded(index, resolvedUrl: resolvedUrl)
            }
        }
        @MainActor func resolvedImageUrl(for index: Int) -> String? {
            parent.viewModel.resolvedImageUrl(for: index)
        }
    }
}

class WebtoonViewController: UIViewController {
    var coordinator: WebtoonReaderView.Coordinator?
    var refererUrl: String?
    var sourceHeaders: [String: String] = [:]

    private var collectionView: UICollectionView!
    private var pages: [Page] = []
    private var currentVisibleIndex: Int = 0
    /// Side padding expressed as a percentage of the collection view width (0–25).
    private var sidePaddingPercent: Double = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupGestures()
    }

    func updatePages(_ newPages: [Page]) {
        if pages.count != newPages.count {
            pages = newPages
            collectionView.reloadData()
        }
    }

    /// Applies horizontal side-padding to all cells.
    /// - Parameter percent: A value in 0–25 representing the percentage of view width on each side.
    func updateSidePadding(_ percent: Double) {
        guard sidePaddingPercent != percent else { return }
        sidePaddingPercent = percent
        collectionView.reloadData()
    }

    // MARK: - Private helpers

    /// Computes the horizontal inset (each side) in points from the current padding percentage.
    private func horizontalInset(for width: CGFloat) -> CGFloat {
        CGFloat(sidePaddingPercent / 100.0) * width
    }

    private func setupCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .black
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.register(WebtoonPageCell.self, forCellWithReuseIdentifier: "page")
        collectionView.contentInsetAdjustmentBehavior = .never
        view.addSubview(collectionView)
    }

    private func createLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(600))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(600))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 0
        return UICollectionViewCompositionalLayout(section: section)
    }

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        collectionView.addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        coordinator?.onTap()
    }
}

extension WebtoonViewController: UICollectionViewDataSource {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int { pages.count }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "page", for: indexPath) as! WebtoonPageCell
        let inset = horizontalInset(for: cv.bounds.width)
        let preResolved = coordinator?.resolvedImageUrl(for: indexPath.item)
        cell.configure(
            with: pages[indexPath.item],
            pageIndex: indexPath.item,
            horizontalInset: inset,
            refererUrl: refererUrl,
            sourceHeaders: sourceHeaders,
            preResolvedImageUrl: preResolved,
            onPageLoaded: { [weak self] idx, resolvedUrl in
                self?.coordinator?.onPageImageLoaded(idx, resolvedUrl: resolvedUrl)
            }
        )
        return cell
    }
}

extension WebtoonViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Track visible page
        let visibleRect = CGRect(origin: collectionView.contentOffset, size: collectionView.bounds.size)
        let centerPoint = CGPoint(x: visibleRect.midX, y: visibleRect.midY)
        if let indexPath = collectionView.indexPathForItem(at: centerPoint) {
            if currentVisibleIndex != indexPath.item {
                currentVisibleIndex = indexPath.item
                coordinator?.onPageVisible(indexPath.item)
            }
        }
    }
}

extension WebtoonViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ cv: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let requests = indexPaths.compactMap { indexPath -> ImageRequest? in
            guard let urlStr = pages[indexPath.item].imageUrl else { return nil }
            let (cleanUrl, fragmentHeaders) = ReaderPageViewController.extractFragmentHeaders(from: urlStr)
            guard let url = URL(string: cleanUrl) else { return nil }
            var urlRequest = URLRequest(url: url)
            for (key, value) in sourceHeaders {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
            if let referer = refererUrl {
                urlRequest.setValue(referer, forHTTPHeaderField: "Referer")
            }
            for (key, value) in fragmentHeaders {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
            return ImageRequest(urlRequest: urlRequest)
        }
        ImagePrefetcher().startPrefetching(with: requests)
    }

    func collectionView(_ cv: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let requests = indexPaths.compactMap { indexPath -> ImageRequest? in
            guard let urlStr = pages[indexPath.item].imageUrl, let url = URL(string: urlStr) else { return nil }
            return ImageRequest(url: url)
        }
        ImagePrefetcher().stopPrefetching(with: requests)
    }
}

// MARK: - WebtoonPageCell

class WebtoonPageCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var loadTask: Task<Void, Never>?
    private var heightConstraint: NSLayoutConstraint?

    /// Tracks the inset so we can detect changes and avoid redundant layout invalidation.
    private var currentHorizontalInset: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        imageView.image = nil
        activityIndicator.startAnimating()
    }

    private func setupViews() {
        contentView.backgroundColor = .black

        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(activityIndicator)
        activityIndicator.startAnimating()

        heightConstraint = contentView.heightAnchor.constraint(equalToConstant: 600)
        heightConstraint?.priority = .defaultHigh

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            heightConstraint!,
        ])
    }

    func configure(
        with page: Page,
        pageIndex: Int,
        horizontalInset: CGFloat,
        refererUrl: String? = nil,
        sourceHeaders: [String: String] = [:],
        preResolvedImageUrl: String? = nil,
        onPageLoaded: ((Int, String?) -> Void)? = nil
    ) {
        // Apply side padding
        if currentHorizontalInset != horizontalInset {
            currentHorizontalInset = horizontalInset
            contentView.layoutMargins = UIEdgeInsets(
                top: 0, left: horizontalInset, bottom: 0, right: horizontalInset
            )
            imageView.leadingAnchor
                .constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor).isActive = true
            imageView.trailingAnchor
                .constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor).isActive = true
        }

        loadTask = Task { [weak self] in
            do {
                // Use pre-resolved URL from prefetch cache, or resolve lazily
                var imageUrlString = preResolvedImageUrl ?? page.imageUrl
                if imageUrlString == nil, !page.url.isEmpty {
                    imageUrlString = await ReaderPageViewController.resolveImageUrl(
                        from: page.url,
                        headers: sourceHeaders
                    )
                }

                let urlString = imageUrlString ?? page.url
                let (cleanUrlString, fragmentHeaders) = ReaderPageViewController.extractFragmentHeaders(from: urlString)
                guard let url = URL(string: cleanUrlString)
                        ?? URL(string: cleanUrlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanUrlString) else { return }

                var urlRequest = URLRequest(url: url)
                for (key, value) in sourceHeaders {
                    urlRequest.setValue(value, forHTTPHeaderField: key)
                }
                if let referer = refererUrl {
                    urlRequest.setValue(referer, forHTTPHeaderField: "Referer")
                    urlRequest.setValue(referer, forHTTPHeaderField: "Origin")
                }
                for (key, value) in fragmentHeaders {
                    urlRequest.setValue(value, forHTTPHeaderField: key)
                }
                let request = ImageRequest(urlRequest: urlRequest)
                let image = try await ImagePipeline.shared.image(for: request)
                guard !Task.isCancelled else { return }
                let resolvedUrl = imageUrlString
                await MainActor.run {
                    self?.displayImage(image, horizontalInset: horizontalInset)
                    onPageLoaded?(pageIndex, resolvedUrl)
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.activityIndicator.stopAnimating()
                }
            }
        }
    }

    private func displayImage(_ image: UIImage, horizontalInset: CGFloat) {
        imageView.image = image
        activityIndicator.stopAnimating()

        // Calculate proper height to maintain aspect ratio at the padded width
        let screenWidth = UIScreen.main.bounds.width
        let paddedWidth = screenWidth - (horizontalInset * 2)
        let effectiveWidth = paddedWidth > 0 ? paddedWidth : screenWidth
        let aspectRatio = image.size.height / max(image.size.width, 1)
        let height = effectiveWidth * aspectRatio
        heightConstraint?.constant = height

        // Force layout update
        setNeedsLayout()
        if let cv = superview as? UICollectionView {
            cv.collectionViewLayout.invalidateLayout()
        }
    }
}
