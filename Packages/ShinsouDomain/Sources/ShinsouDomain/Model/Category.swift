import Foundation

public struct Category: Identifiable, Sendable, Equatable {
    public let id: Int64
    public let name: String
    public let sort: Int
    public let flags: Int64

    public var isSystemCategory: Bool { id <= 0 }

    public init(id: Int64 = 0, name: String = "", sort: Int = 0, flags: Int64 = 0) {
        self.id = id
        self.name = name
        self.sort = sort
        self.flags = flags
    }

    public static let `default` = Category(id: 0, name: "Default", sort: 0, flags: 0)
}
