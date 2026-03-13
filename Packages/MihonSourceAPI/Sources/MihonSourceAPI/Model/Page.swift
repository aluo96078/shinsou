import Foundation

public struct Page: Sendable, Equatable {
    public let index: Int
    public var url: String
    public var imageUrl: String?

    public init(index: Int, url: String = "", imageUrl: String? = nil) {
        self.index = index
        self.url = url
        self.imageUrl = imageUrl
    }
}
