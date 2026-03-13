import SwiftUI
import MihonDomain
import MihonSourceAPI
import NukeUI

struct MigrationSearchScreen: View {
    let manga: Manga

    @StateObject private var viewModel: MigrationSearchViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmSheet = false
    @State private var pendingMigration: (SManga, Int64)?

    init(manga: Manga) {
        self.manga = manga
        _viewModel = StateObject(
            wrappedValue: MigrationSearchViewModel(manga: manga)
        )
    }

    var body: some View {
        ScrollView {
            if viewModel.isSearching && viewModel.results.isEmpty {
                ProgressView("Searching sources…")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else if viewModel.results.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No results found.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(viewModel.results) { group in
                        sourceSection(group)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Migrate: \(manga.title)")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isMigrating {
                migrationOverlay
            }
        }
        .alert("Migration Complete", isPresented: $viewModel.migrationSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Manga successfully migrated to the new source.")
        }
        .alert("Migration Failed", isPresented: .init(
            get: { viewModel.migrationError != nil },
            set: { if !$0 { viewModel.migrationError = nil } }
        )) {
            Button("OK") { viewModel.migrationError = nil }
        } message: {
            Text(viewModel.migrationError ?? "")
        }
        .confirmationDialog(
            "Migrate to this manga?",
            isPresented: $showConfirmSheet,
            titleVisibility: .visible
        ) {
            Button("Migrate", role: .destructive) {
                if let (target, sourceId) = pendingMigration {
                    Task { await viewModel.migrate(to: target, sourceId: sourceId) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let (target, _) = pendingMigration {
                Text("Replace \"\(manga.title)\" with \"\(target.title)\"? Read status, categories and tracks will be copied.")
            }
        }
        .task { await viewModel.smartSearch() }
    }

    // MARK: - Source Section

    private func sourceSection(_ group: MigrationSearchGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.sourceName)
                    .font(.headline)
                Spacer()
                if group.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("\(group.results.count) result(s)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !group.results.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(Array(group.results.prefix(10).enumerated()), id: \.element.url) { _, candidate in
                            candidateCard(candidate, sourceId: group.sourceId)
                        }
                    }
                }
            } else if let error = group.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else if !group.isLoading {
                Text("No matches found.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
        }
    }

    private func candidateCard(_ candidate: SManga, sourceId: Int64) -> some View {
        Button {
            pendingMigration = (candidate, sourceId)
            showConfirmSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                coverThumbnail(candidate)
                Text(candidate.title)
                    .font(.caption2)
                    .lineLimit(2)
                    .frame(width: 100)
                    .foregroundStyle(.primary)
                if let author = candidate.author {
                    Text(author)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: 100)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func coverThumbnail(_ manga: SManga) -> some View {
        if let urlStr = manga.thumbnailUrl, let url = URL(string: urlStr) {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholderCover
                }
            }
            .frame(width: 100, height: 150)
            .clipped()
            .cornerRadius(8)
        } else {
            placeholderCover
                .frame(width: 100, height: 150)
                .cornerRadius(8)
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

    // MARK: - Migration Overlay

    private var migrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                Text("Migrating…")
                    .foregroundStyle(.white)
                    .font(.headline)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}
