import Foundation

public typealias FilterList = [Filter]

public enum Filter: Sendable {
    case header(name: String)
    case separator
    case select(name: String, values: [String], state: Int)
    case text(name: String, state: String)
    case checkBox(name: String, state: Bool)
    case triState(name: String, state: TriStateValue)
    case group(name: String, filters: [Filter])
    case sort(name: String, values: [String], selection: SortSelection?)

    public enum TriStateValue: Int, Sendable {
        case ignore = 0
        case include = 1
        case exclude = 2
    }

    public struct SortSelection: Sendable, Equatable {
        public let index: Int
        public let ascending: Bool

        public init(index: Int, ascending: Bool) {
            self.index = index
            self.ascending = ascending
        }
    }
}
