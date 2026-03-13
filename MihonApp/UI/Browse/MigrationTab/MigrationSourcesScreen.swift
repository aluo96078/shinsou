import SwiftUI
import MihonDomain

struct MigrationSourcesScreen: View {
    @StateObject private var viewModel = MigrationSourcesViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.sources.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No sources with library manga found.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.sources) { source in
                    NavigationLink(value: source) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.name)
                                    .font(.body)
                                Text("ID: \(source.id)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Text("\(source.mangaCount)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Select Source")
        .navigationDestination(for: MigrationSource.self) { source in
            MigrationMangaListScreen(sourceId: source.id, sourceName: source.name)
        }
        .task { await viewModel.load() }
    }
}

struct MigrationSource: Identifiable, Hashable {
    let id: Int64
    let name: String
    let mangaCount: Int
}
