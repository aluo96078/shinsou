import SwiftUI

public struct AdaptiveColumns: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let minWidth: CGFloat

    public init(minWidth: CGFloat = 110) {
        self.minWidth = minWidth
    }

    public func body(content: Content) -> some View {
        content
    }

    public var columns: [GridItem] {
        [GridItem(.adaptive(minimum: minWidth), spacing: 12)]
    }
}

public extension View {
    func adaptiveGrid(minWidth: CGFloat = 110) -> some View {
        modifier(AdaptiveColumns(minWidth: minWidth))
    }
}
