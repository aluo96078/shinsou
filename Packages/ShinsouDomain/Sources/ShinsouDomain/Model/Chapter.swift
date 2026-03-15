import Foundation

public struct Chapter: Identifiable, Sendable, Equatable {
    public let id: Int64
    public let mangaId: Int64
    public let url: String
    public let name: String
    public let scanlator: String?
    public let read: Bool
    public let bookmark: Bool
    public let lastPageRead: Int
    public let chapterNumber: Double
    public let sourceOrder: Int
    public let dateFetch: Int64
    public let dateUpload: Int64
    public let lastModifiedAt: Int64
    public let version: Int64

    public init(
        id: Int64 = -1,
        mangaId: Int64 = -1,
        url: String = "",
        name: String = "",
        scanlator: String? = nil,
        read: Bool = false,
        bookmark: Bool = false,
        lastPageRead: Int = 0,
        chapterNumber: Double = -1,
        sourceOrder: Int = 0,
        dateFetch: Int64 = 0,
        dateUpload: Int64 = 0,
        lastModifiedAt: Int64 = 0,
        version: Int64 = 1
    ) {
        self.id = id; self.mangaId = mangaId; self.url = url
        self.name = name; self.scanlator = scanlator; self.read = read
        self.bookmark = bookmark; self.lastPageRead = lastPageRead
        self.chapterNumber = chapterNumber; self.sourceOrder = sourceOrder
        self.dateFetch = dateFetch; self.dateUpload = dateUpload
        self.lastModifiedAt = lastModifiedAt; self.version = version
    }
}
