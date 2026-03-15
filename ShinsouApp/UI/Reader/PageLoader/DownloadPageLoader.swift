import Foundation
import ShinsouSourceAPI

/// Loads pages from a downloaded chapter directory on disk.
/// Image files inside the directory are sorted by filename.
final class DownloadPageLoader: PageLoader {

    private let chapterDirectory: URL

    /// - Parameter chapterDirectory: The directory URL that contains the downloaded image files.
    init(chapterDirectory: URL) {
        self.chapterDirectory = chapterDirectory
    }

    // MARK: - PageLoader

    func getPages() async throws -> [ReaderPage] {
        let imageURLs = try loadImageURLs()
        return imageURLs.enumerated().map { index, url in
            let page = Page(index: index, url: url.absoluteString, imageUrl: url.absoluteString)
            return ReaderPage(index: index, page: page)
        }
    }

    func loadPage(_ page: ReaderPage) async throws {
        await MainActor.run { page.state = .loading }

        // The URL is already a local file URL — mark it ready immediately.
        if let imageUrl = page.page.imageUrl, let url = URL(string: imageUrl) {
            await MainActor.run {
                page.imageURL = url
                page.state    = .ready(url: url)
            }
            return
        }

        if let url = URL(string: page.page.url) {
            await MainActor.run {
                page.imageURL = url
                page.state    = .ready(url: url)
            }
        } else {
            await MainActor.run {
                page.state = .error("Invalid local file URL")
            }
        }
    }

    func cancel() {
        // No active tasks to cancel for local file loading.
    }

    // MARK: - Private helpers

    private static let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "avif"]

    private func loadImageURLs() throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: chapterDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let imageFiles = contents.filter { url in
            Self.supportedExtensions.contains(url.pathExtension.lowercased())
        }

        return imageFiles.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
