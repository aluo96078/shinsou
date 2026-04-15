import UIKit
import ShinsouI18n
import Nuke
import ShinsouSourceAPI

class ReaderPageViewController: UIViewController {
    var pageIndex: Int?
    var page: Page?
    var refererUrl: String?
    var sourceHeaders: [String: String] = [:]
    var sourceId: Int64?

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
                        headers: self?.sourceHeaders ?? [:],
                        sourceId: self?.sourceId
                    )
                }

                let urlString = imageUrlString ?? page.url

                // Extract per-page headers encoded in the URL fragment
                // Format: "https://...#Header-Name=value&Another=value2"
                let (cleanUrlString, fragmentHeaders) = Self.extractFragmentHeaders(from: urlString)

                // Build request — route through proxy if enabled
                var mergedHeaders = self?.sourceHeaders ?? [:]
                for (key, value) in fragmentHeaders {
                    mergedHeaders[key] = value
                }
                guard var urlRequest = NetworkHelper.shared.imageURLRequest(
                    for: cleanUrlString,
                    headers: mergedHeaders,
                    referer: self?.refererUrl,
                    sourceId: self?.sourceId
                ) else {
                    throw URLError(.badURL)
                }
                if ignoreCache {
                    urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
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
    static func resolveImageUrl(from viewerUrl: String, headers: [String: String], sourceId: Int64? = nil) async -> String? {
        guard var request = NetworkHelper.shared.imageURLRequest(
            for: viewerUrl, headers: headers, sourceId: sourceId
        ) else { return nil }
        request.setValue("text/html,application/xhtml+xml,*/*;q=0.8", forHTTPHeaderField: "Accept")

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
        label.text = MR.strings.readerLoadFailed
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
        retryButton.setTitle(MR.strings.readerRetry, for: .normal)
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
        // Nuke wraps errors in ImagePipeline.Error — pattern match to extract the real cause
        if let pipelineError = error as? ImagePipeline.Error {
            switch pipelineError {
            case .dataLoadingFailed(let innerError):
                return "資料載入失敗\n\(Self.underlyingErrorDescription(innerError))"
            case .dataIsEmpty:
                return "伺服器回傳空資料"
            case .dataMissingInCache:
                return "快取中無資料"
            case .decoderNotRegistered:
                return "無可用的圖片解碼器"
            case .decodingFailed(_, _, let innerError):
                return "圖片解碼失敗\n\(Self.underlyingErrorDescription(innerError))"
            case .processingFailed(_, _, let innerError):
                return "圖片處理失敗\n\(Self.underlyingErrorDescription(innerError))"
            case .imageRequestMissing:
                return "圖片請求遺失（無 URL）"
            case .pipelineInvalidated:
                return "圖片管線已失效"
            @unknown default:
                return pipelineError.description
            }
        }
        return Self.underlyingErrorDescription(error)
    }

    /// Format a non-Nuke error (URLError, DataLoader.Error, etc.) into readable text.
    private static func underlyingErrorDescription(_ error: Error) -> String {
        if let urlError = error as? URLError {
            let reason: String
            switch urlError.code {
            case .notConnectedToInternet: reason = "無網路連線"
            case .timedOut:               reason = "連線逾時"
            case .cannotFindHost:         reason = "找不到伺服器"
            case .cannotConnectToHost:    reason = "無法連線至伺服器"
            case .networkConnectionLost:  reason = "網路連線中斷"
            case .dnsLookupFailed:        reason = "DNS 解析失敗"
            case .secureConnectionFailed: reason = "SSL 連線失敗"
            case .badServerResponse:      reason = "伺服器回應異常"
            case .badURL:                 reason = "無效的 URL"
            case .cancelled:              reason = "請求已取消"
            default:                      reason = urlError.localizedDescription
            }
            return "[\(urlError.code.rawValue)] \(reason)"
        }
        // DataLoader.Error.statusCodeUnacceptable — bridge through description
        if let dataLoaderError = error as? DataLoader.Error {
            return dataLoaderError.description
        }
        // Fallback: recurse into NSUnderlyingErrorKey if available
        let nsError = error as NSError
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return "[\(nsError.domain) \(nsError.code)] \(Self.underlyingErrorDescription(underlying))"
        }
        return nsError.localizedDescription
    }

    @objc private func retryLoadImage() {
        errorContainer?.removeFromSuperview()
        errorContainer = nil
        loadTask?.cancel()
        loadImage(ignoreCache: true)
    }
}
