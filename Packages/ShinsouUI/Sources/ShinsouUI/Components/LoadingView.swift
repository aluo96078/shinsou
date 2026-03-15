import SwiftUI

public struct LoadingView: View {
    public init() {}

    public var body: some View {
        VStack {
            ProgressView()
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct EmptyStateView: View {
    let icon: String
    let message: String

    public init(icon: String = "tray", message: String) {
        self.icon = icon
        self.message = message
    }

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
