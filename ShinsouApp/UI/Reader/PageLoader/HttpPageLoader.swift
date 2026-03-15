import Foundation
import ShinsouSourceAPI

final class HttpPageLoader: PageLoader {
    private let source: Source
    private let chapter: SChapter
    private var tasks: [Task<Void, Never>] = []

    init(source: Source, chapter: SChapter) {
        self.source  = source
        self.chapter = chapter
    }

    func getPages() async throws -> [ReaderPage] {
        let pages = try await source.getPageList(chapter: chapter)
        return pages.enumerated().map { index, page in
            ReaderPage(index: index, page: page)
        }
    }

    func loadPage(_ page: ReaderPage) async throws {
        await MainActor.run { page.state = .loading }

        // If imageUrl is already set, use it directly
        if let imageUrl = page.page.imageUrl, let url = URL(string: imageUrl) {
            await MainActor.run {
                page.imageURL = url
                page.state    = .ready(url: url)
            }
            return
        }

        // Otherwise resolve from page.url
        // Some sources require a second network request (source-specific)
        if let url = URL(string: page.page.url) {
            await MainActor.run {
                page.imageURL = url
                page.state    = .ready(url: url)
            }
        } else {
            await MainActor.run {
                page.state = .error("Invalid URL")
            }
        }
    }

    func cancel() {
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }
}
