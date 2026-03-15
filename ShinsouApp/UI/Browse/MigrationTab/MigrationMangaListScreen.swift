import SwiftUI
import ShinsouDomain
import ShinsouI18n
import Nuke
import NukeUI

struct MigrationMangaListScreen: View {
    let sourceId: Int64
    let sourceName: String

    @StateObject private var viewModel: MigrationMangaListViewModel

    init(sourceId: Int64, sourceName: String) {
        self.sourceId = sourceId
        self.sourceName = sourceName
        _viewModel = StateObject(
            wrappedValue: MigrationMangaListViewModel(sourceId: sourceId)
        )
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.mangas.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(MR.strings.migrationNoManga)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.mangas) { manga in
                    NavigationLink(value: manga) {
                        mangaRow(manga)
                    }
                }
            }
        }
        .navigationTitle(sourceName)
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Manga.self) { manga in
            MigrationSearchScreen(manga: manga)
        }
        .task { await viewModel.load() }
    }

    private func mangaRow(_ manga: Manga) -> some View {
        HStack(spacing: 12) {
            coverImage(manga)
            VStack(alignment: .leading, spacing: 4) {
                Text(manga.title)
                    .font(.body)
                    .lineLimit(2)
                if let author = manga.author {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "arrow.right.circle")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func coverImage(_ manga: Manga) -> some View {
        if let urlStr = manga.thumbnailUrl, let url = URL(string: urlStr) {
            LazyImage(request: .proxied(url: url)) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholderCover
                }
            }
            .frame(width: 44, height: 62)
            .clipped()
            .cornerRadius(6)
        } else {
            placeholderCover
                .frame(width: 44, height: 62)
                .cornerRadius(6)
        }
    }

    private var placeholderCover: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "book.closed")
                    .foregroundStyle(.secondary)
            }
    }
}
