import Foundation

public struct MangasPage: Sendable {
    public let mangas: [SManga]
    public let hasNextPage: Bool

    public init(mangas: [SManga], hasNextPage: Bool) {
        self.mangas = mangas
        self.hasNextPage = hasNextPage
    }
}
