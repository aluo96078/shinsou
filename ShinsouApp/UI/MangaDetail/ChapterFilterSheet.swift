import SwiftUI
import ShinsouI18n

struct ChapterFilterSheet: View {
    @ObservedObject var viewModel: MangaDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showScanlatorFilter = false

    var body: some View {
        NavigationStack {
            List {
                Section(MR.strings.actionFilter) {
                    Toggle("Show \(MR.strings.mangaRead)", isOn: $viewModel.showRead)
                    Toggle("Show \(MR.strings.mangaUnread)", isOn: $viewModel.showUnread)
                    Toggle("Show \(MR.strings.mangaBookmark)", isOn: $viewModel.showBookmarked)
                    Toggle("Show \(MR.strings.libraryDownloaded)", isOn: $viewModel.showDownloaded)
                }

                Section(MR.strings.chapterScanlators) {
                    Button {
                        showScanlatorFilter = true
                    } label: {
                        HStack {
                            Label(MR.strings.mangaFilterScanlator, systemImage: "person.2")
                            Spacer()
                            if !viewModel.excludedScanlators.isEmpty {
                                Text(MR.strings.chapterHiddenCount(viewModel.excludedScanlators.count))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                Section(MR.strings.actionSort) {
                    Picker(MR.strings.actionSort, selection: $viewModel.sortAscending) {
                        Text(MR.strings.mangaSortDescending).tag(false)
                        Text(MR.strings.mangaSortAscending).tag(true)
                    }
                }

                // MARK: Chapter Skip Settings (7.12)
                Section {
                    Toggle(isOn: $viewModel.skipReadChapters) {
                        Label(MR.strings.mangaSkipRead, systemImage: "eye.slash")
                    }
                    Toggle(isOn: $viewModel.skipFilteredChapters) {
                        Label(MR.strings.mangaSkipFiltered, systemImage: "line.3.horizontal.decrease")
                    }
                    Toggle(isOn: $viewModel.skipDuplicateChapters) {
                        Label(MR.strings.mangaSkipDuplicate, systemImage: "doc.on.doc")
                    }
                } header: {
                    Text(MR.strings.mangaReaderSkip)
                } footer: {
                    Text(MR.strings.mangaReaderSkipFooter)
                }
            }
            .navigationTitle(MR.strings.actionFilter)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(MR.strings.commonDone) {
                        viewModel.refreshSortFilter()
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $showScanlatorFilter) {
                ScanlatorFilterSheet(viewModel: viewModel)
            }
        }
    }
}
