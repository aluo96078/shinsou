import Foundation

public protocol MangaRepository: Sendable {
    func getManga(id: Int64) async throws -> Manga?
    func getMangaByUrlAndSource(url: String, sourceId: Int64) async throws -> Manga?
    func getFavorites() async throws -> [Manga]
    func getLibraryManga() async throws -> [LibraryManga]

    func observeLibraryManga() -> AsyncStream<[LibraryManga]>
    func observeManga(id: Int64) -> AsyncStream<Manga?>

    func insert(manga: Manga) async throws -> Int64
    func update(manga: Manga) async throws
    func updatePartial(id: Int64, updates: MangaUpdate) async throws
    func delete(mangaId: Int64) async throws
}

public struct MangaUpdate: Sendable {
    public var favorite: Bool?
    public var title: String?
    public var author: String?
    public var artist: String?
    public var description: String?
    public var genre: [String]?
    public var status: Int64?
    public var chapterFlags: Int64?
    public var viewerFlags: Int64?
    public var notes: String?
    public var dateAdded: Int64?
    public var thumbnailUrl: String?
    public var initialized: Bool?

    public init(
        favorite: Bool? = nil, title: String? = nil,
        author: String? = nil, artist: String? = nil,
        description: String? = nil, genre: [String]? = nil,
        status: Int64? = nil,
        chapterFlags: Int64? = nil, viewerFlags: Int64? = nil,
        notes: String? = nil, dateAdded: Int64? = nil,
        thumbnailUrl: String? = nil, initialized: Bool? = nil
    ) {
        self.favorite = favorite; self.title = title
        self.author = author; self.artist = artist
        self.description = description; self.genre = genre
        self.status = status
        self.chapterFlags = chapterFlags; self.viewerFlags = viewerFlags
        self.notes = notes; self.dateAdded = dateAdded
        self.thumbnailUrl = thumbnailUrl; self.initialized = initialized
    }
}
