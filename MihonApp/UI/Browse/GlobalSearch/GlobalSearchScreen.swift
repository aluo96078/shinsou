import SwiftUI
import MihonSourceAPI
import MihonUI
import MihonI18n
import NukeUI

struct GlobalSearchScreen: View {
    @StateObject private var viewModel = GlobalSearchViewModel()

    var body: some View {
        ScrollView {
            if viewModel.results.isEmpty && !viewModel.isSearching {
                EmptyStateView(icon: "magnifyingglass", message: MR.strings.browseSearchAcross)
                    .padding(.top, 100)
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.results) { result in
                        sourceResultSection(result)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(MR.strings.browseGlobalSearch)
        .searchable(text: $viewModel.query, prompt: MR.strings.browseSearchAll)
        .onSubmit(of: .search) {
            Task { await viewModel.search() }
        }
    }

    private func sourceResultSection(_ result: GlobalSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.sourceName)
                    .font(.headline)
                Spacer()
                if result.isLoading {
                    ProgressView()
                } else {
                    Text("\(result.mangas.count) results")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !result.mangas.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(Array(result.mangas.prefix(10).enumerated()), id: \.element.url) { _, manga in
                            VStack(alignment: .leading) {
                                if let url = manga.thumbnailUrl, let imageUrl = URL(string: url) {
                                    LazyImage(url: imageUrl) { state in
                                        if let image = state.image {
                                            image.resizable().scaledToFill()
                                        } else {
                                            Rectangle().fill(Color.gray.opacity(0.2))
                                        }
                                    }
                                    .frame(width: 100, height: 150)
                                    .clipped()
                                    .cornerRadius(6)
                                } else {
                                    Rectangle().fill(Color.gray.opacity(0.2))
                                        .frame(width: 100, height: 150)
                                        .cornerRadius(6)
                                }
                                Text(manga.title)
                                    .font(.caption2)
                                    .lineLimit(2)
                                    .frame(width: 100)
                            }
                        }
                    }
                }
            } else if let error = result.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()
        }
    }
}

struct GlobalSearchResult: Identifiable {
    let id: Int64
    let sourceName: String
    var mangas: [SManga] = []
    var isLoading: Bool = true
    var error: String?
}

@MainActor
final class GlobalSearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var results: [GlobalSearchResult] = []
    @Published var isSearching = false

    func search() async {
        guard !query.isEmpty else { return }
        isSearching = true

        let sources = SourceManager.shared.catalogueSources
        results = sources.map { GlobalSearchResult(id: $0.id, sourceName: $0.name) }

        // Search each source concurrently with limit
        await withTaskGroup(of: (Int64, [SManga]?, String?).self) { group in
            for source in sources {
                group.addTask {
                    do {
                        let result = try await source.getSearchManga(page: 1, query: self.query, filters: [])
                        return (source.id, result.mangas, nil)
                    } catch {
                        return (source.id, nil, error.localizedDescription)
                    }
                }
            }

            for await (sourceId, mangas, error) in group {
                if let idx = results.firstIndex(where: { $0.id == sourceId }) {
                    results[idx].isLoading = false
                    results[idx].mangas = mangas ?? []
                    results[idx].error = error
                }
            }
        }

        isSearching = false
    }
}
