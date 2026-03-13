import UIKit
import Nuke
import MihonSourceAPI

class ReaderPageViewController: UIViewController {
    var pageIndex: Int?
    var page: Page?
    var refererUrl: String?
    var sourceHeaders: [String: String] = [:]

    /// Tap callbacks — center toggles menu, left/right navigate pages.
    var onTapCenter: (() -> Void)?
    var onTapLeft: (() -> Void)?
    var onTapRight: (() -> Void)?

    /// Called when the page image finishes loading, with the resolved image URL.
    var onPageLoaded: ((Int, String?) -> Void)?

    /// Pre-resolved image URL from the prefetch cache (avoids redundant resolution).
    var preResolvedImageUrl: String?

    private let imageView = UIImageView()
    private var loadTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupImageView()
        setupGestures()
        loadImage()
    }

    deinit {
        loadTask?.cancel()
    }

    // MARK: - Setup

    private func setupImageView() {
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupGestures() {
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        view.addGestureRecognizer(singleTap)
    }

    // MARK: - Gesture Handlers

    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        let width = view.bounds.width
        let tapZone = width / 3.0

        if location.x < tapZone {
            // Left third → previous page
            onTapLeft?()
        } else if location.x > width - tapZone {
            // Right third → next page
            onTapRight?()
        } else {
            // Center third → toggle menu
            onTapCenter?()
        }
    }

    // MARK: - Image Loading

    private func loadImage(ignoreCache: Bool = false) {
        guard let page else { return }

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        spinner.startAnimating()

        loadTask = Task { [weak self] in
            do {
                // Use pre-resolved URL from prefetch cache, or resolve lazily
                var imageUrlString = self?.preResolvedImageUrl ?? page.imageUrl
                if imageUrlString == nil, !page.url.isEmpty {
                    imageUrlString = await Self.resolveImageUrl(
                        from: page.url,
                        headers: self?.sourceHeaders ?? [:]
                    )
                }

                let urlString = imageUrlString ?? page.url

                // Extract per-page headers encoded in the URL fragment
                // Format: "https://...#Header-Name=value&Another=value2"
                let (cleanUrlString, fragmentHeaders) = Self.extractFragmentHeaders(from: urlString)

                guard let url = URL(string: cleanUrlString)
                        ?? URL(string: cleanUrlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanUrlString) else {
                    throw URLError(.badURL)
                }

                var urlRequest = URLRequest(url: url)
                if ignoreCache {
                    urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
                }
                // Apply source headers (User-Agent, Cookie, Referer, etc.)
                if let headers = self?.sourceHeaders {
                    for (key, value) in headers {
                        urlRequest.setValue(value, forHTTPHeaderField: key)
                    }
                }
                if let referer = self?.refererUrl {
                    urlRequest.setValue(referer, forHTTPHeaderField: "Referer")
                    urlRequest.setValue(referer, forHTTPHeaderField: "Origin")
                }
                // Apply per-page headers from URL fragment
                for (key, value) in fragmentHeaders {
                    urlRequest.setValue(value, forHTTPHeaderField: key)
                }
                var request = ImageRequest(urlRequest: urlRequest)
                if ignoreCache {
                    request.options = [.reloadIgnoringCachedData]
                }
                let response = try await ImagePipeline.shared.image(for: request)
                guard !Task.isCancelled else { return }
                let resolvedUrl = imageUrlString
                let idx = self?.pageIndex
                await MainActor.run {
                    spinner.removeFromSuperview()
                    self?.imageView.image = response
                    if let idx {
                        self?.onPageLoaded?(idx, resolvedUrl)
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    spinner.removeFromSuperview()
                    self?.showError(error, url: nil)
                }
            }
        }
    }

    /// Resolve the actual image URL from a viewer/intermediate page.
    /// Fetches the HTML and extracts `<img id="img" src="...">`.
    static func resolveImageUrl(from viewerUrl: String, headers: [String: String]) async -> String? {
        guard let url = URL(string: viewerUrl) else { return nil }
        var request = URLRequest(url: url)
        // Apply all source headers (User-Agent, Cookie, Referer, etc.)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            return Self.extractImageSrc(from: html)
        } catch {
            return nil
        }
    }

    /// Extract per-page HTTP headers encoded in the URL fragment.
    /// Plugins can encode headers as: `https://cdn.example.com/img.jpg#X-Token=abc&X-Other=def`
    /// Returns the clean URL (without fragment) and a dictionary of extracted headers.
    static func extractFragmentHeaders(from urlString: String) -> (String, [String: String]) {
        guard let hashIndex = urlString.firstIndex(of: "#") else {
            return (urlString, [:])
        }
        let cleanUrl = String(urlString[urlString.startIndex..<hashIndex])
        let fragment = String(urlString[urlString.index(after: hashIndex)...])
        var headers: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).removingPercentEncoding ?? String(parts[0])
            let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
            headers[key] = value
        }
        return (cleanUrl, headers)
    }

    /// Fast regex extraction of image src from E-Hentai viewer page HTML.
    static func extractImageSrc(from html: String) -> String? {
        // Pattern: <img id="img" ... src="URL">
        let patterns = [
            #"<img[^>]+id="img"[^>]+src="([^"]+)""#,
            #"id="img"[^>]+src="([^"]+)""#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: html) else { continue }
            return String(html[range])
        }
        return nil
    }

    private var errorContainer: UIView?

    private func showError(_ error: Error, url: URL? = nil) {
        errorContainer?.removeFromSuperview()

        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center
        container.spacing = 12
        container.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.heightAnchor.constraint(equalToConstant: 32).isActive = true
        icon.widthAnchor.constraint(equalToConstant: 32).isActive = true
        container.addArrangedSubview(icon)

        let label = UILabel()
        label.text = "載入失敗"
        label.textColor = .white
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        container.addArrangedSubview(label)

        // Build detailed error message
        var errorText = Self.detailedErrorDescription(error)
        if let url {
            errorText += "\n\nURL: \(url.absoluteString)"
        }

        let errorLabel = UILabel()
        errorLabel.text = errorText
        errorLabel.textColor = .white.withAlphaComponent(0.5)
        errorLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 8
        errorLabel.lineBreakMode = .byTruncatingMiddle
        container.addArrangedSubview(errorLabel)

        let retryButton = UIButton(type: .system)
        retryButton.setTitle("重試", for: .normal)
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        retryButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        retryButton.layer.cornerRadius = 18
        retryButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 24, bottom: 8, right: 24)
        retryButton.addTarget(self, action: #selector(retryLoadImage), for: .touchUpInside)
        container.addArrangedSubview(retryButton)

        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        errorContainer = container
    }

    /// Extract a human-readable description from Nuke pipeline errors, including the underlying cause.
    private static func detailedErrorDescription(_ error: Error) -> String {
        // Nuke wraps errors in ImagePipeline.Error — dig into underlying error
        let nsError = error as NSError
        var parts: [String] = []

        // Top-level description
        parts.append(nsError.localizedDescription)

        // Check for underlying errors
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            let underNS = underlying as NSError
            parts.append("[\(underNS.domain) \(underNS.code)] \(underNS.localizedDescription)")

            // HTTP status code from URLError
            if underNS.domain == NSURLErrorDomain {
                parts.append("NSURLError code: \(underNS.code)")
            }
        }

        return parts.joined(separator: "\n")
    }

    @objc private func retryLoadImage() {
        errorContainer?.removeFromSuperview()
        errorContainer = nil
        loadTask?.cancel()
        loadImage(ignoreCache: true)
    }
}
