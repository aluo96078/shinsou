import SwiftUI
import ShinsouDomain
import ShinsouI18n
import Nuke
import NukeUI

/// iPad 專用的漫畫詳情雙欄佈局
/// 左欄：封面圖片 + 元資料（標題、作者、繪者、狀態、來源）
/// 右欄：章節列表（含篩選/排序控制）
struct MangaDetailIPadLayout: View {
    @ObservedObject var viewModel: MangaDetailViewModel
    @State private var showChapterFilterSheet = false

    var body: some View {
        Group {
            if let manga = viewModel.manga {
                splitContent(manga)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Manga not found")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showChapterFilterSheet) {
            ChapterFilterSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
    }

    // MARK: - 雙欄主體

    private func splitContent(_ manga: Manga) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // 左欄：封面 + 詳細資訊，固定寬度 360pt
            leftPanel(manga)
                .frame(width: 360)

            Divider()

            // 右欄：章節列表
            rightPanel
        }
    }

    // MARK: - 左欄

    private func leftPanel(_ manga: Manga) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 大型封面圖片
                largeCoverImage(manga)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                // 標題與基本資訊
                mangaMetadata(manga)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                // 動作按鈕列
                actionButtons(manga)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Divider()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                // 劇情簡介
                if let desc = manga.description, !desc.isEmpty {
                    descriptionSection(desc)
                        .padding(.horizontal, 20)
                }

                // 標籤/類型
                if let genres = manga.genre, !genres.isEmpty {
                    genresSection(genres)
                        .padding(.top, 8)
                }

                Spacer(minLength: 20)
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 封面圖片（大尺寸）

    private func largeCoverImage(_ manga: Manga) -> some View {
        GeometryReader { geo in
            Group {
                if let url = manga.thumbnailUrl, let imageUrl = URL(string: url) {
                    LazyImage(request: .proxied(url: imageUrl)) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            coverPlaceholder
                        }
                    }
                } else {
                    coverPlaceholder
                }
            }
            .frame(width: geo.size.width, height: geo.size.width * 1.4)
            .clipped()
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .aspectRatio(1.0 / 1.4, contentMode: .fit)
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "book.closed")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
    }

    // MARK: - 漫畫元資料

    private func mangaMetadata(_ manga: Manga) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 標題
            Text(manga.title)
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

            // 作者
            if let author = manga.author {
                Label(author, systemImage: "person")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // 繪者（當與作者不同時才顯示）
            if let artist = manga.artist, artist != manga.author {
                Label(artist, systemImage: "paintbrush")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // 狀態徽章 + 來源
            HStack(spacing: 8) {
                statusBadge(for: manga.status)

                Text("•")
                    .foregroundStyle(.tertiary)

                Text(MR.strings.mangaSourceId(manga.source))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func statusBadge(for status: Int64) -> some View {
        let (text, color) = statusInfo(status)
        return Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .cornerRadius(6)
    }

    private func statusInfo(_ status: Int64) -> (String, Color) {
        switch status {
        case 1: return ("Ongoing", .blue)
        case 2: return ("Completed", .green)
        case 3: return ("Licensed", .orange)
        case 4: return ("Publishing Finished", .purple)
        case 5: return ("Cancelled", .red)
        case 6: return ("On Hiatus", .yellow)
        default: return ("Unknown", .gray)
        }
    }

    // MARK: - 動作按鈕

    private func actionButtons(_ manga: Manga) -> some View {
        HStack(spacing: 0) {
            // 加入收藏
            actionButton(
                icon: viewModel.isFavorite ? "heart.fill" : "heart",
                label: viewModel.isFavorite ? MR.strings.mangaInLibrary : MR.strings.mangaAddToLibrary,
                tint: viewModel.isFavorite ? .red : .secondary
            ) {
                Task { await viewModel.toggleFavorite() }
            }

            // 追蹤
            actionButton(
                icon: "arrow.triangle.2.circlepath",
                label: MR.strings.mangaTracking,
                tint: .secondary
            ) {
                // TODO: 開啟追蹤 sheet
            }

            // WebView
            actionButton(
                icon: "safari",
                label: MR.strings.mangaWebview,
                tint: .secondary
            ) {
                // TODO: 開啟 WebView
            }
        }
    }

    private func actionButton(icon: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 劇情簡介

    private func descriptionSection(_ description: String) -> some View {
        MangaDescriptionSection(description: description)
            .padding(0)
    }

    // MARK: - 類型標籤

    private func genresSection(_ genres: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(MR.strings.mangaGenres)
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)

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
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - 右欄（章節列表）

    private var rightPanel: some View {
        VStack(spacing: 0) {
            // 章節標頭：計數 + 篩選/排序控制
            chapterHeader
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))

            Divider()

            // 章節清單
            if viewModel.chapters.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "book")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(MR.strings.mangaNoChapters)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                chapterList
            }
        }
    }

    private var chapterHeader: some View {
        HStack(spacing: 12) {
            Text(MR.strings.mangaChaptersCount(viewModel.chapters.count))
                .font(.headline)

            Spacer()

            // 排序方向按鈕
            Button {
                viewModel.sortAscending.toggle()
                viewModel.refreshSortFilter()
            } label: {
                Image(systemName: viewModel.sortAscending ? "arrow.up" : "arrow.down")
                    .font(.body)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)

            // 篩選按鈕
            Button {
                showChapterFilterSheet = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.body)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)

            // 全選/清除選擇
            if viewModel.isSelectionMode {
                Button("Done") {
                    viewModel.clearSelection()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    viewModel.selectAll()
                } label: {
                    Text("Select All")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var chapterList: some View {
        List {
            ForEach(viewModel.chapters) { chapter in
                ChapterRow(
                    chapter: chapter,
                    isSelected: viewModel.selectedChapterIds.contains(chapter.id),
                    isSelectionMode: viewModel.isSelectionMode,
                    onTap: {
                        if viewModel.isSelectionMode {
                            viewModel.toggleSelection(chapter.id)
                        } else {
                            // TODO: 導向閱讀器
                        }
                    },
                    onLongPress: {
                        viewModel.toggleSelection(chapter.id)
                    }
                )
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.visible)
            }
        }
        .listStyle(.plain)
        // 批次操作工具列（選擇模式時顯示）
        .safeAreaInset(edge: .bottom) {
            if viewModel.isSelectionMode {
                batchActionBar
            }
        }
    }

    // MARK: - 批次操作列（選擇模式）

    private var batchActionBar: some View {
        HStack(spacing: 0) {
            batchButton(icon: "eye", label: "Mark Read") {
                Task {
                    await viewModel.markChaptersRead(
                        Array(viewModel.selectedChapterIds),
                        read: true
                    )
                    viewModel.clearSelection()
                }
            }

            Divider().frame(height: 40)

            batchButton(icon: "eye.slash", label: "Mark Unread") {
                Task {
                    await viewModel.markChaptersRead(
                        Array(viewModel.selectedChapterIds),
                        read: false
                    )
                    viewModel.clearSelection()
                }
            }

            Divider().frame(height: 40)

            batchButton(icon: "bookmark", label: "Bookmark") {
                Task {
                    await viewModel.toggleBookmark(Array(viewModel.selectedChapterIds))
                    viewModel.clearSelection()
                }
            }

            Divider().frame(height: 40)

            batchButton(icon: "trash", label: "Delete", role: .destructive) {
                Task {
                    await viewModel.deleteChapters(Array(viewModel.selectedChapterIds))
                    viewModel.clearSelection()
                }
            }
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func batchButton(icon: String, label: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}
