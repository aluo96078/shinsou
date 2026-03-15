import Foundation
import ShinsouSourceAPI

enum PageState: Equatable {
    case queue
    case loading
    case downloadImage(progress: Double)
    case ready(url: URL)
    case error(String)
}

protocol PageLoader {
    func getPages() async throws -> [ReaderPage]
    func loadPage(_ page: ReaderPage) async throws
    func cancel()
}

final class ReaderPage: Identifiable, ObservableObject {
    let id: Int
    let page: Page
    @Published var state: PageState = .queue
    @Published var imageURL: URL?

    init(index: Int, page: Page) {
        self.id   = index
        self.page = page
    }
}
