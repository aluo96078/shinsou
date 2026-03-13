import SwiftUI

struct MangaDescriptionSection: View {
    let description: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(isExpanded ? nil : 3)

            Button(isExpanded ? "Show less" : "Show more") {
                withAnimation { isExpanded.toggle() }
            }
            .font(.caption)
        }
        .padding()
    }
}
