import Foundation

public struct SChapter: Sendable, Equatable {
    public var url: String
    public var name: String
    public var scanlator: String?
    public var dateUpload: Int64
    public var chapterNumber: Double

    public init(
        url: String = "",
        name: String = "",
        scanlator: String? = nil,
        dateUpload: Int64 = 0,
        chapterNumber: Double = -1
    ) {
        self.url = url
        self.name = name
        self.scanlator = scanlator
        self.dateUpload = dateUpload
        self.chapterNumber = chapterNumber
    }
}
