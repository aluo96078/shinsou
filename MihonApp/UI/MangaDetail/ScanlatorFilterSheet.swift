import SwiftUI
import MihonI18n

/// Displayed as a navigation destination inside ChapterFilterSheet's NavigationStack.
struct ScanlatorFilterSheet: View {
    @ObservedObject var viewModel: MangaDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if viewModel.availableScanlators.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(MR.strings.mangaFilterScanlator)
                        .font(.headline)
                    Text(MR.strings.mangaShowAllScanlators)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    Section {
                        ForEach(viewModel.availableScanlators.sorted(), id: \.self) { scanlator in
                            Button {
                                viewModel.toggleExcludedScanlator(scanlator)
                            } label: {
                                HStack {
                                    Text(scanlator)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if viewModel.excludedScanlators.contains(scanlator) {
                                        Image(systemName: "eye.slash")
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Image(systemName: "eye")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } footer: {
                        Text(MR.strings.mangaShowAllScanlators)
                    }

                    if !viewModel.excludedScanlators.isEmpty {
                        Section {
                            Button(role: .destructive) {
                                viewModel.excludedScanlators.removeAll()
                                viewModel.refreshSortFilter()
                            } label: {
                                Label(MR.strings.mangaShowAllScanlators, systemImage: "eye")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(MR.strings.mangaFilterScanlator)
        .navigationBarTitleDisplayMode(.inline)
    }
}
