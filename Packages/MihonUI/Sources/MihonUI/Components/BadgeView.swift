import SwiftUI

public struct BadgeView: View {
    let count: Int
    let color: Color

    public init(count: Int, color: Color = .accentColor) {
        self.count = count
        self.color = color
    }

    public var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color, in: Capsule())
        }
    }
}
