import SwiftUI
import ShinsouDomain
import ShinsouUI
import ShinsouI18n

struct MangaDetailScreen: View {
    @StateObject private var viewModel: MangaDetailViewModel
    @State private var showChapterFilterSheet = false
    @State private var showNotesSheet = false
    @State private var readerChapterId: Int64? = nil
    @Environment(\.dismiss) private var dismiss

    init(mangaId: Int64) {
        _viewModel = StateObject(wrappedValue: MangaDetailViewModel(
            mangaId: mangaId,
            mangaRepository: DIContainer.shared.mangaRepository,
            chapterRepository: DIContainer.shared.chapterRepository,
            categoryRepository: DIContainer.shared.categoryRepository
        ))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else if let manga = viewModel.manga {
                    mangaContent(manga)
                } else {
                    EmptyStateView(icon: "exclamationmark.triangle", message: MR.strings.mangaStatusUnknown)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating "Continue Reading" button
            if !viewModel.isLoading && !viewModel.isSelectionMode,
               let chapter = viewModel.continueReadingChapter {
                Button {
                    readerChapterId = chapter.id
                } label: {
                    Label(viewModel.continueReadingLabel, systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showChapterFilterSheet) {
            ChapterFilterSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showNotesSheet) {
            MangaNotesSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $viewModel.showCategoryPicker) {
            CategoryPickerSheet(
                categoryRepository: viewModel.categoryRepository,
                mangaIds: [viewModel.mangaId]
            )
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: Binding(
            get: { readerChapterId != nil },
            set: { if !$0 { readerChapterId = nil } }
        )) {
            if let chapterId = readerChapterId {
                ReaderContainerView(mangaId: viewModel.mangaId, chapterId: chapterId)
            }
        }
    }

    @ViewBuilder
    private func mangaContent(_ manga: Manga) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Source refresh indicator
                if viewModel.isRefreshingFromSource {
                    ProgressView()
                        .padding(.vertical, 8)
                }

                // Cover + Info header
                MangaInfoHeader(manga: manga, isFavorite: viewModel.isFavorite) {
                    Task { await viewModel.toggleFavorite() }
                }

                Divider().padding(.horizontal)

                // Description
                if let desc = manga.description, !desc.isEmpty {
                    MangaDescriptionSection(description: desc)
                    Divider().padding(.horizontal)
                }

                // Genres
                if let genres = manga.genre, !genres.isEmpty {
                    MangaGenresSection(genres: genres)
                    Divider().padding(.horizontal)
                }

                // Notes preview (7.3)
                if !manga.notes.isEmpty {
                    notesPreview(manga.notes)
                    Divider().padding(.horizontal)
                }

                // Chapter header
                chapterHeader

                // Chapter list with missing-chapter indicators (7.9) and duplicate badges (7.11)
                chapterListContent
            }
        }
        .refreshable {
            await viewModel.refreshFromSource()
        }
    }

    // MARK: - Notes Preview (7.3)

    private func notesPreview(_ notes: String) -> some View {
        Button {
            showNotesSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(MR.strings.mangaNotes, systemImage: "note.text")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chapter List (7.9, 7.11)

    @ViewBuilder
    private var chapterListContent: some View {
        let duplicateIds = viewModel.duplicateChapterIds
        let gaps = viewModel.missingChapterRanges
        let chaptersWithIndex = Array(viewModel.chapters.enumerated())

        ForEach(chaptersWithIndex, id: \.element.id) { index, chapter in
            // Missing chapters indicator before this chapter (7.9)
            if let gap = gapBefore(index: index, in: viewModel.chapters, gaps: gaps) {
                MissingChaptersDivider(from: gap.0, to: gap.1)
            }

            ChapterRow(
                chapter: chapter,
                isSelected: viewModel.selectedChapterIds.contains(chapter.id),
                isSelectionMode: viewModel.isSelectionMode,
                isDuplicate: duplicateIds.contains(chapter.id),
                onTap: {
                    if viewModel.isSelectionMode {
                        viewModel.toggleSelection(chapter.id)
                    } else {
                        readerChapterId = chapter.id
                    }
                },
                onLongPress: {
                    viewModel.toggleSelection(chapter.id)
                }
            )
            Divider().padding(.leading, 16)
        }
    }

    /// Returns the gap that should be displayed immediately before the chapter at `index`.
    private func gapBefore(
        index: Int,
        in chapters: [Chapter],
        gaps: [(Double, Double)]
    ) -> (Double, Double)? {
        guard index > 0 else { return nil }
        let prevNum = chapters[index - 1].chapterNumber
        let currNum = chapters[index].chapterNumber

        let lo = min(prevNum, currNum)
        let hi = max(prevNum, currNum)
        return gaps.first(where: { abs($0.0 - lo) < 1e-9 && abs($0.1 - hi) < 1e-9 })
    }

    // MARK: - Chapter Header

    private var chapterHeader: some View {
        HStack {
            Text(MR.strings.mangaChaptersCount(viewModel.chapters.count))
                .font(.headline)

            // Duplicate count badge (7.11)
            if !viewModel.duplicateChapterGroups.isEmpty {
                Text(MR.strings.mangaDuplicatesCount(viewModel.duplicateChapterGroups.count))
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .cornerRadius(4)
                    .contextMenu {
                        Button {
                            Task { await viewModel.autoMarkAllDuplicatesRead() }
                        } label: {
                            Label(MR.strings.mangaMarkDuplicatesRead, systemImage: "checkmark.circle")
                        }
                    }
            }

            Spacer()
            Button { showChapterFilterSheet = true } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            Button {
                viewModel.sortAscending.toggle()
                viewModel.refreshSortFilter()
            } label: {
                Image(systemName: viewModel.sortAscending ? "arrow.up" : "arrow.down")
            }
        }
        .padding()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if viewModel.isSelectionMode {
            ToolbarItem(placement: .topBarLeading) {
                Text(MR.strings.librarySelectedCount(viewModel.selectedChapterIds.count))
                    .font(.headline)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(MR.strings.commonDone) { viewModel.clearSelection() }
            }
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Button {
                        Task { await viewModel.markChaptersRead(Array(viewModel.selectedChapterIds), read: true) }
                    } label: {
                        Label(MR.strings.mangaRead, systemImage: "eye")
                    }
                    Spacer()
                    Button {
                        Task { await viewModel.markChaptersRead(Array(viewModel.selectedChapterIds), read: false) }
                    } label: {
                        Label(MR.strings.mangaUnread, systemImage: "eye.slash")
                    }
                    Spacer()
                    Button {
                        Task { await viewModel.toggleBookmark(Array(viewModel.selectedChapterIds)) }
                    } label: {
                        Label(MR.strings.mangaBookmark, systemImage: "bookmark")
                    }
                    Spacer()
                    Button(role: .destructive) {
                        Task { await viewModel.deleteChapters(Array(viewModel.selectedChapterIds)) }
                    } label: {
                        Label(MR.strings.actionDelete, systemImage: "trash")
                    }
                }
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await viewModel.toggleFavorite() }
                    } label: {
                        Label(
                            viewModel.isFavorite ? MR.strings.libraryRemoveFromLibrary : MR.strings.mangaAddToLibrary,
                            systemImage: viewModel.isFavorite ? "heart.fill" : "heart"
                        )
                    }

                    // Notes edit (7.3)
                    Button {
                        showNotesSheet = true
                    } label: {
                        Label(MR.strings.mangaEditNotes, systemImage: "note.text")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}
