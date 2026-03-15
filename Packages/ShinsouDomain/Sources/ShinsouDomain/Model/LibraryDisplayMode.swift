import Foundation

public enum LibraryDisplayMode: Int, Codable, Sendable {
    case compactGrid = 0
    case comfortableGrid = 1
    case list = 2
    case coverOnlyGrid = 3

    public static let `default` = LibraryDisplayMode.compactGrid
}
