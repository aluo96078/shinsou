import Foundation
import ShinsouDomain
import ShinsouSourceAPI
import ShinsouCore

enum DownloadState: Equatable {
    case queued
    case downloading(progress: Double)
    case downloaded
    case error(String)
}

struct DownloadItem: Identifiable, Equatable {
    let id: String // "\(mangaId)_\(chapterId)"
    let manga: Manga
    let chapter: Chapter
    var state: DownloadState = .queued
    var pages: [Page] = []
    var downloadedPages: Int = 0
    var totalPages: Int = 0

    static func == (lhs: DownloadItem, rhs: DownloadItem) -> Bool {
        lhs.id == rhs.id && lhs.state == rhs.state && lhs.downloadedPages == rhs.downloadedPages
    }
}

@MainActor
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published var queue: [DownloadItem] = []
    @Published var isRunning = false

    private var activeTasks: [String: Task<Void, Never>] = [:]
    private let maxConcurrentSources = AppConstants.maxConcurrentSourceDownloads
    private let maxConcurrentPages = AppConstants.maxConcurrentPageDownloads

    private init() {}

    // MARK: - Queue Management

    func enqueue(manga: Manga, chapters: [Chapter]) {
        for chapter in chapters {
            let id = "\(manga.id)_\(chapter.id)"
            guard !queue.contains(where: { $0.id == id }) else { continue }
            let item = DownloadItem(id: id, manga: manga, chapter: chapter)
            queue.append(item)
        }

        if !isRunning {
            startDownloading()
        }
    }

    func remove(itemId: String) {
        activeTasks[itemId]?.cancel()
        activeTasks.removeValue(forKey: itemId)
        queue.removeAll { $0.id == itemId }
    }

    func clearCompleted() {
        queue.removeAll { $0.state == .downloaded }
    }

    func cancelAll() {
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        queue.removeAll()
        isRunning = false
    }

    func pauseAll() {
        isRunning = false
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }

    func resumeAll() {
        startDownloading()
    }

    func reorder(from source: IndexSet, to destination: Int) {
        queue.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Download Logic

    private func startDownloading() {
        isRunning = true
        processQueue()
    }

    private func processQueue() {
        guard isRunning else { return }

        let activeCount = activeTasks.count
        let available = maxConcurrentSources - activeCount

        guard available > 0 else { return }

        let pending = queue.filter { item in
            if case .queued = item.state { return true }
            return false
        }

        for item in pending.prefix(available) {
            let task = Task { [weak self] in
                guard let self else { return }
                await self.downloadChapter(item)
            }
            activeTasks[item.id] = task
        }

        if pending.isEmpty && activeTasks.isEmpty {
            isRunning = false
        }
    }

    private func downloadChapter(_ item: DownloadItem) async {
        guard let index = queue.firstIndex(where: { $0.id == item.id }) else { return }

        // Update state to downloading
        queue[index].state = .downloading(progress: 0)

        do {
            // Get source
            guard let source = DIContainer.shared.sourceManager.getSource(id: item.manga.source) else {
                queue[index].state = .error("Source not found")
                activeTasks.removeValue(forKey: item.id)
                processQueue()
                return
            }

            // Get page list
            let sChapter = SChapter(url: item.chapter.url)
            let pages = try await source.getPageList(chapter: sChapter)

            guard let idx = queue.firstIndex(where: { $0.id == item.id }) else { return }
            queue[idx].totalPages = pages.count
            queue[idx].pages = pages

            // Create download directory
            let downloadDir = DiskUtil.downloadsDirectory()
                .appendingPathComponent("\(item.manga.id)")
                .appendingPathComponent("\(item.chapter.id)")
            try FileManager.default.createDirectory(at: downloadDir, withIntermediateDirectories: true)

            // Download pages concurrently with limit
            await withTaskGroup(of: (Int, Bool).self) { group in
                var activeTasks = 0

                for (pageIndex, page) in pages.enumerated() {
                    if activeTasks >= self.maxConcurrentPages {
                        if let result = await group.next() {
                            activeTasks -= 1
                            if result.1, let idx = self.queue.firstIndex(where: { $0.id == item.id }) {
                                self.queue[idx].downloadedPages += 1
                                let progress = Double(self.queue[idx].downloadedPages) / Double(pages.count)
                                self.queue[idx].state = .downloading(progress: progress)
                            }
                        }
                    }

                    group.addTask {
                        do {
                            let urlString = page.imageUrl ?? page.url
                            guard let url = URL(string: urlString) else { return (pageIndex, false) }

                            let (data, _) = try await URLSession.shared.data(from: url)
                            let filePath = downloadDir.appendingPathComponent(String(format: "%03d.jpg", pageIndex))
                            try data.write(to: filePath)
                            return (pageIndex, true)
                        } catch {
                            return (pageIndex, false)
                        }
                    }
                    activeTasks += 1
                }

                // Collect remaining
                for await result in group {
                    if result.1, let idx = self.queue.firstIndex(where: { $0.id == item.id }) {
                        self.queue[idx].downloadedPages += 1
                        let progress = Double(self.queue[idx].downloadedPages) / Double(pages.count)
                        self.queue[idx].state = .downloading(progress: progress)
                    }
                }
            }

            // Mark as completed
            if let idx = queue.firstIndex(where: { $0.id == item.id }) {
                queue[idx].state = .downloaded
            }
        } catch {
            if let idx = queue.firstIndex(where: { $0.id == item.id }) {
                queue[idx].state = .error(error.localizedDescription)
            }
        }

        activeTasks.removeValue(forKey: item.id)
        processQueue()
    }

    // MARK: - Query

    func isChapterDownloaded(mangaId: Int64, chapterId: Int64) -> Bool {
        let dir = DiskUtil.downloadsDirectory()
            .appendingPathComponent("\(mangaId)")
            .appendingPathComponent("\(chapterId)")
        return FileManager.default.fileExists(atPath: dir.path)
    }

    func getDownloadedPageURLs(mangaId: Int64, chapterId: Int64) -> [URL] {
        let dir = DiskUtil.downloadsDirectory()
            .appendingPathComponent("\(mangaId)")
            .appendingPathComponent("\(chapterId)")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return [] }
        return contents
            .filter { ["jpg", "jpeg", "png", "webp", "gif"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func deleteDownload(mangaId: Int64, chapterId: Int64) {
        let dir = DiskUtil.downloadsDirectory()
            .appendingPathComponent("\(mangaId)")
            .appendingPathComponent("\(chapterId)")
        try? FileManager.default.removeItem(at: dir)
    }
}
