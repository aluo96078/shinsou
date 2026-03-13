import SwiftUI
import MihonDomain
import MihonI18n
import NukeUI

// MARK: - TrackSearchSheet

struct TrackSearchSheet: View {
    let mangaId: Int64
    let tracker: IdentifiableTracker
    let onBind: (TrackSearch) -> Void

    @State private var query: String = ""
    @State private var results: [TrackSearch] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    ProgressView(MR.strings.trackSearching)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if results.isEmpty && !query.isEmpty {
                    emptyState
                } else {
                    resultsList
                }
            }
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search \(tracker.tracker.name)"
            )
            .onSubmit(of: .search) {
                Task { await search() }
            }
            .navigationTitle("\(MR.strings.actionSearch) \(tracker.tracker.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(MR.strings.commonCancel) { dismiss() }
                }
            }
            .alert(MR.strings.commonError, isPresented: Binding(
                get: { searchError != nil },
                set: { if !$0 { searchError = nil } }
            )) {
                Button(MR.strings.commonOk, role: .cancel) { searchError = nil }
            } message: {
                Text(searchError ?? "")
            }
        }
    }

    // MARK: - Views

    private var resultsList: some View {
        List(results) { result in
            Button {
                onBind(result)
                dismiss()
            } label: {
                TrackSearchResultRow(result: result)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(MR.strings.trackNoResults)
                .font(.headline)
            Text(MR.strings.trackTryDifferent)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Search

    private func search() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await tracker.tracker.search(query: query)
        } catch {
            searchError = error.localizedDescription
        }
    }
}

// MARK: - TrackSearchResultRow

private struct TrackSearchResultRow: View {
    let result: TrackSearch

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            coverImage
                .frame(width: 56, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(radius: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)

                if !result.publishingType.isEmpty {
                    Text(result.publishingType.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    if result.totalChapters > 0 {
                        Label("\(result.totalChapters) ch", systemImage: "book.closed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !result.publishingStatus.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(result.publishingStatus.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !result.startDate.isEmpty {
                        Text("•")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(result.startDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !result.summary.isEmpty {
                    Text(result.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var coverImage: some View {
        if let url = URL(string: result.coverUrl), !result.coverUrl.isEmpty {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholderCover
                }
            }
        } else {
            placeholderCover
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
