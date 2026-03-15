import Foundation
import ShinsouSourceAPI

/// Loads pages from a local directory (used by LocalSource).
/// Scans for image files (.jpg, .jpeg, .png, .gif, .webp) and sorts them by filename.
final class DirectoryPageLoader: PageLoader {

    private let directory: URL

    /// - Parameter directory: The directory to scan for image files.
    init(directory: URL) {
        self.directory = directory
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

        let urlString = page.page.imageUrl ?? page.page.url
        if let url = URL(string: urlString) {
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
        // No active tasks to cancel for local directory loading.
    }

    // MARK: - Private helpers

    private static let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "avif"]

    private func loadImageURLs() throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        )

        let imageFiles = contents.filter { url in
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                return false
            }
            return Self.supportedExtensions.contains(url.pathExtension.lowercased())
        }

        // Sort by natural order so "page10" comes after "page9", not "page1"
        return imageFiles.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }
}
