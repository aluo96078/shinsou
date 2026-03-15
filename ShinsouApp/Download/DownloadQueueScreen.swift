import SwiftUI
import ShinsouDomain
import ShinsouUI

struct DownloadQueueScreen: View {
    @ObservedObject private var downloadManager = DownloadManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if downloadManager.queue.isEmpty {
                    EmptyStateView(icon: "arrow.down.circle", message: "No downloads")
                } else {
                    downloadList
                }
            }
            .navigationTitle("Downloads")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if downloadManager.isRunning {
                            Button { downloadManager.pauseAll() } label: {
                                Label("Pause all", systemImage: "pause.circle")
                            }
                        } else {
                            Button { downloadManager.resumeAll() } label: {
                                Label("Resume all", systemImage: "play.circle")
                            }
                        }
                        Button { downloadManager.clearCompleted() } label: {
                            Label("Clear completed", systemImage: "checkmark.circle")
                        }
                        Button(role: .destructive) { downloadManager.cancelAll() } label: {
                            Label("Cancel all", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var downloadList: some View {
        List {
            ForEach(downloadManager.queue) { item in
                DownloadItemRow(item: item)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            downloadManager.remove(itemId: item.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
            .onMove { source, destination in
                downloadManager.reorder(from: source, to: destination)
            }
        }
        .listStyle(.plain)
    }
}

private struct DownloadItemRow: View {
    let item: DownloadItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.manga.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(item.chapter.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack {
                stateView
                Spacer()
                if item.totalPages > 0 {
                    Text("\(item.downloadedPages)/\(item.totalPages)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var stateView: some View {
        switch item.state {
        case .queued:
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text("Queued")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

        case .downloading(let progress):
            ProgressView(value: progress)
                .tint(Color.accentColor)

        case .downloaded:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                Text("Downloaded")
                    .font(.caption)
            }
            .foregroundStyle(.green)

        case .error(let msg):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption2)
                Text(msg)
                    .font(.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(.red)
        }
    }
}
