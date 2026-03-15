import SwiftUI
import ShinsouDomain
import ShinsouI18n
import Nuke
import NukeUI
import UIKit
import Photos

struct MangaInfoHeader: View {
    let manga: Manga
    let isFavorite: Bool
    let onToggleFavorite: () -> Void

    // Cover image actions state (7.1)
    @State private var loadedCoverImage: UIImage? = nil
    @State private var showShareSheet = false
    @State private var customCoverSavedMessage: String? = nil
    @State private var showSaveSuccessAlert = false
    @State private var saveAlertMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Cover + basic info
            HStack(alignment: .top, spacing: 16) {
                // Cover image with long-press context menu (7.1)
                coverImageWithActions
                    .frame(width: 120, height: 180)
                    .clipped()
                    .cornerRadius(8)
                    .shadow(radius: 4)

                // Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(manga.title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .lineLimit(3)

                    if let author = manga.author {
                        Label(author, systemImage: "person")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let artist = manga.artist, artist != manga.author {
                        Label(artist, systemImage: "paintbrush")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        statusBadge
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(MR.strings.mangaSourceId(manga.source))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding()

            // Action buttons
            HStack(spacing: 0) {
                actionButton(
                    icon: isFavorite ? "heart.fill" : "heart",
                    label: isFavorite ? MR.strings.mangaInLibrary : MR.strings.mangaAddToLibrary,
                    tint: isFavorite ? .red : .secondary
                ) {
                    onToggleFavorite()
                }

                actionButton(
                    icon: "arrow.triangle.2.circlepath",
                    label: MR.strings.mangaTracking,
                    tint: .secondary
                ) {
                    // TODO: open tracking sheet
                }

                actionButton(
                    icon: "safari",
                    label: MR.strings.mangaWebview,
                    tint: .secondary
                ) {
                    // TODO: open webview
                }
            }
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = loadedCoverImage {
                ShareSheet(items: [image])
            }
        }
        .alert(MR.strings.mangaCoverImage, isPresented: $showSaveSuccessAlert) {
            Button(MR.strings.commonOk) {}
        } message: {
            Text(saveAlertMessage)
        }
    }

    // MARK: - Cover with Context Menu (7.1)

    @ViewBuilder
    private var coverImageWithActions: some View {
        coverImageContent
            .contextMenu {
                Button {
                    saveCoverToPhotos()
                } label: {
                    Label(MR.strings.mangaSaveToPhotos, systemImage: "square.and.arrow.down")
                }

                Button {
                    showShareSheet = true
                } label: {
                    Label(MR.strings.actionShare, systemImage: "square.and.arrow.up")
                }

                Button {
                    saveCustomCover()
                } label: {
                    Label(MR.strings.mangaSetCustomCover, systemImage: "photo.badge.checkmark")
                }
            }
    }

    @ViewBuilder
    private var coverImageContent: some View {
        if let url = manga.thumbnailUrl, let imageUrl = URL(string: url) {
            LazyImage(request: Self.sourceImageRequest(url: imageUrl, sourceId: manga.source)) { state in
                if let image = state.image {
                    image.resizable().scaledToFill()
                        .onAppear {
                            // Cache the UIImage for context menu actions
                            if let uiImage = state.imageContainer?.image {
                                loadedCoverImage = uiImage
                            }
                        }
                } else {
                    placeholderCover
                }
            }
        } else {
            placeholderCover
        }
    }

    /// Build an ImageRequest with source-specific headers for cover loading.
    private static func sourceImageRequest(url: URL, sourceId: Int64) -> ImageRequest {
        var headers: [String: String] = [:]
        if let jsProxy = SourceManager.shared.getCatalogueSource(id: sourceId) as? JSSourceProxy {
            headers = jsProxy.sourceHeaders
        }
        if let urlRequest = NetworkHelper.shared.imageURLRequest(for: url.absoluteString, headers: headers) {
            return ImageRequest(urlRequest: urlRequest)
        }
        return ImageRequest(url: url)
    }

    private var placeholderCover: some View {
        Rectangle().fill(Color.gray.opacity(0.2))
            .overlay { Image(systemName: "book.closed").foregroundStyle(.secondary) }
    }

    // MARK: - Cover Image Actions

    private func saveCoverToPhotos() {
        guard let image = loadedCoverImage else {
            saveAlertMessage = MR.strings.mangaCoverNotLoaded
            showSaveSuccessAlert = true
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                if status == .authorized || status == .limited {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    saveAlertMessage = MR.strings.mangaCoverSaved
                } else {
                    saveAlertMessage = MR.strings.mangaPhotosDenied
                }
                showSaveSuccessAlert = true
            }
        }
    }

    private func saveCustomCover() {
        guard let image = loadedCoverImage else {
            saveAlertMessage = MR.strings.mangaCoverNotLoaded
            showSaveSuccessAlert = true
            return
        }
        let fileName = "custom_cover_\(manga.id).jpg"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(fileName)
        if let data = image.jpegData(compressionQuality: 0.9) {
            do {
                try data.write(to: fileURL)
                saveAlertMessage = MR.strings.mangaCustomCoverSaved
            } catch {
                saveAlertMessage = "Failed to save custom cover: \(error.localizedDescription)"
            }
        } else {
            saveAlertMessage = MR.strings.mangaEncodeFailed
        }
        showSaveSuccessAlert = true
    }

    // MARK: - Subviews

    private var statusBadge: some View {
        let (text, color) = mangaStatusInfo(manga.status)
        return Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .cornerRadius(4)
    }

    private func mangaStatusInfo(_ status: Int64) -> (String, Color) {
        switch status {
        case 1: return (MR.strings.mangaStatusOngoing, .blue)
        case 2: return (MR.strings.mangaStatusCompleted, .green)
        case 3: return (MR.strings.mangaStatusLicensed, .orange)
        case 4: return (MR.strings.mangaStatusPublishingFinished, .purple)
        case 5: return (MR.strings.mangaStatusCancelled, .red)
        case 6: return (MR.strings.mangaStatusOnHiatus, .yellow)
        default: return (MR.strings.mangaStatusUnknown, .gray)
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
        }
    }
}

// MARK: - UIActivityViewController wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
