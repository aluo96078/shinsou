import SwiftUI
import MihonDomain
import MihonI18n
import NukeUI

// MARK: - TrackSheet

struct TrackSheet: View {
    let mangaId: Int64

    @StateObject private var viewModel: TrackSheetViewModel
    @Environment(\.dismiss) private var dismiss

    init(mangaId: Int64) {
        self.mangaId = mangaId
        _viewModel = StateObject(wrappedValue: TrackSheetViewModel(mangaId: mangaId))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.trackerStates) { state in
                    TrackerRow(
                        state: state,
                        onBind: {
                            viewModel.showSearch(for: state.tracker)
                        },
                        onRemove: {
                            Task { await viewModel.removeTrack(tracker: state.tracker) }
                        },
                        onStatusChange: { status in
                            Task { await viewModel.updateStatus(tracker: state.tracker, status: status) }
                        },
                        onScoreChange: { score in
                            Task { await viewModel.updateScore(tracker: state.tracker, score: score) }
                        },
                        onChapterChange: { chapter in
                            Task { await viewModel.updateChapter(tracker: state.tracker, chapter: chapter) }
                        }
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(MR.strings.trackTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(MR.strings.commonDone) { dismiss() }
                }
            }
            // Search sheet – shown only when tracker is logged in
            .sheet(item: $viewModel.searchingTracker) { identifiable in
                TrackSearchSheet(
                    mangaId: mangaId,
                    tracker: identifiable,
                    onBind: { search in
                        Task { await viewModel.bind(tracker: identifiable.tracker, search: search) }
                    }
                )
            }
            // Login sheet – shown when tracker is not logged in
            .sheet(item: $viewModel.loginTracker) { identifiable in
                TrackerLoginSheet(tracker: identifiable) {
                    // After successful login, open the search sheet
                    viewModel.loginTracker = nil
                    viewModel.searchingTracker = identifiable
                }
            }
            .alert(MR.strings.commonError, isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button(MR.strings.commonOk, role: .cancel) { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
        .task { await viewModel.loadTracks() }
    }
}

// MARK: - TrackerRow

private struct TrackerRow: View {
    let state: TrackerState
    let onBind: () -> Void
    let onRemove: () -> Void
    let onStatusChange: (TrackStatus) -> Void
    let onScoreChange: (Double) -> Void
    let onChapterChange: (Double) -> Void

    var body: some View {
        if let track = state.track {
            boundContent(track: track)
        } else {
            unboundContent
        }
    }

    // MARK: Unbound

    private var unboundContent: some View {
        HStack(spacing: 12) {
            trackerLogo
            Text(state.tracker.name)
                .font(.headline)
            Spacer()
            Button(action: onBind) {
                Label(MR.strings.trackAdd, systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    // MARK: Bound

    private func boundContent(track: Track) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row: logo + tracker name + remove button
            HStack(spacing: 10) {
                trackerLogo
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.tracker.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(track.title)
                        .font(.headline)
                        .lineLimit(2)
                }
                Spacer()
                Button(role: .destructive, action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Status picker
            statusRow(track: track)

            // Score picker
            scoreRow(track: track)

            // Chapter stepper
            chapterRow(track: track)

            // Dates (if tracker supports them)
            if state.tracker.supportsReadingDates {
                datesRow(track: track)
            }
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onRemove) {
                Label(MR.strings.commonRemove, systemImage: "trash")
            }
        }
    }

    // MARK: Status Row

    private func statusRow(track: Track) -> some View {
        let statuses = state.tracker.getStatusList()
        let currentStatus = TrackStatus(rawValue: track.status)

        return HStack {
            Label(MR.strings.trackStatus, systemImage: "bookmark")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Spacer()
            Menu {
                ForEach(statuses, id: \.rawValue) { status in
                    Button {
                        onStatusChange(status)
                    } label: {
                        if currentStatus == status {
                            Label(status.displayName, systemImage: "checkmark")
                        } else {
                            Text(status.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currentStatus?.displayName ?? "—")
                        .font(.subheadline)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.primary)
            }
        }
    }

    // MARK: Score Row

    private func scoreRow(track: Track) -> some View {
        let scoreList = state.tracker.getScoreList()
        let displayScore = state.tracker.displayScore(score: track.score)

        return HStack {
            Label(MR.strings.trackScore, systemImage: "star")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Spacer()
            Menu {
                ForEach(Array(scoreList.enumerated()), id: \.offset) { index, label in
                    Button {
                        onScoreChange(state.tracker.indexToScore(index: index))
                    } label: {
                        Text(label.isEmpty ? "—" : label)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(displayScore.isEmpty ? "—" : displayScore)
                        .font(.subheadline)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.primary)
            }
        }
    }

    // MARK: Chapter Row

    private func chapterRow(track: Track) -> some View {
        HStack {
            Label(MR.strings.trackChapter, systemImage: "book")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Spacer()
            HStack(spacing: 12) {
                Button {
                    let next = max(0, track.lastChapterRead - 1)
                    onChapterChange(next)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .disabled(track.lastChapterRead <= 0)

                let total = track.totalChapters > 0 ? "/\(track.totalChapters)" : ""
                Text("\(Int(track.lastChapterRead))\(total)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .frame(minWidth: 44, alignment: .center)

                Button {
                    let maxChapter = track.totalChapters > 0 ? Double(track.totalChapters) : Double.infinity
                    let next = min(track.lastChapterRead + 1, maxChapter)
                    onChapterChange(next)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
                .disabled(track.totalChapters > 0 && track.lastChapterRead >= Double(track.totalChapters))
            }
        }
    }

    // MARK: Dates Row

    private func datesRow(track: Track) -> some View {
        VStack(spacing: 6) {
            if track.startDate > 0 {
                HStack {
                    Label(MR.strings.trackStarted, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .leading)
                    Spacer()
                    Text(formattedDate(from: track.startDate))
                        .font(.subheadline)
                }
            }
            if track.finishDate > 0 {
                HStack {
                    Label(MR.strings.trackFinished, systemImage: "calendar.badge.checkmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .leading)
                    Spacer()
                    Text(formattedDate(from: track.finishDate))
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: Tracker Logo

    private var trackerLogo: some View {
        Image(systemName: state.tracker.logoName)
            .resizable()
            .scaledToFit()
            .frame(width: 28, height: 28)
            .foregroundStyle(Color.accentColor)
    }

    // MARK: Helpers

    private func formattedDate(from epoch: Int64) -> String {
        guard epoch > 0 else { return "—" }
        let date = Date(timeIntervalSince1970: TimeInterval(epoch) / 1000)
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
