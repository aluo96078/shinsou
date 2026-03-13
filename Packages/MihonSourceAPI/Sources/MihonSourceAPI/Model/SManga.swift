import Foundation

public struct SManga: Sendable, Equatable {
    public var url: String
    public var title: String
    public var artist: String?
    public var author: String?
    public var description: String?
    public var genre: [String]?
    public var status: MangaStatus
    public var thumbnailUrl: String?
    public var updateStrategy: UpdateStrategy
    public var initialized: Bool

    public init(
        url: String = "",
        title: String = "",
        artist: String? = nil,
        author: String? = nil,
        description: String? = nil,
        genre: [String]? = nil,
        status: MangaStatus = .unknown,
        thumbnailUrl: String? = nil,
        updateStrategy: UpdateStrategy = .alwaysUpdate,
        initialized: Bool = false
    ) {
        self.url = url
        self.title = title
        self.artist = artist
        self.author = author
        self.description = description
        self.genre = genre
        self.status = status
        self.thumbnailUrl = thumbnailUrl
        self.updateStrategy = updateStrategy
        self.initialized = initialized
    }
}

public enum MangaStatus: Int, Sendable, Codable {
    case unknown = 0
    case ongoing = 1
    case completed = 2
    case licensed = 3
    case publishingFinished = 4
    case cancelled = 5
    case onHiatus = 6
}

public enum UpdateStrategy: Int, Sendable, Codable {
    case alwaysUpdate = 0
    case onlyFetchOnce = 1
}
