import SwiftUI

struct MangaGenresSection: View {
    let genres: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(genres, id: \.self) { genre in
                    Text(genre)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
}
