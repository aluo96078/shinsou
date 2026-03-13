import Foundation

public struct UpdateItem: Identifiable, Sendable {
    public var id: Int64 { chapter.id }
    public let manga: Manga
    public let chapter: Chapter

    public init(manga: Manga, chapter: Chapter) {
        self.manga = manga
        self.chapter = chapter
    }
}
