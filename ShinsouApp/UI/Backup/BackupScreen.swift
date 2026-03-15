import SwiftUI
import UniformTypeIdentifiers
import ShinsouDomain
import ShinsouI18n

// MARK: - BackupScreen

struct BackupScreen: View {

    @StateObject private var viewModel = BackupViewModel()

    var body: some View {
        NavigationStack {
            List {
                actionsSection
                autoBackupsSection
            }
            .navigationTitle(MR.strings.backupTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .fileImporter(
                isPresented: $viewModel.isShowingFilePicker,
                allowedContentTypes: [.shinsouBackup, .mihonBackupLegacy],
                allowsMultipleSelection: false
            ) { result in
                viewModel.handleFileImport(result)
            }
            .sheet(item: $viewModel.shareItem) { item in
                ShareSheet(items: [item.url])
            }
            .sheet(item: $viewModel.pendingRestoreURL) { pending in
                RestoreOptionsSheet(
                    pendingURL: pending,
                    preview: viewModel.backupPreview,
                    options: $viewModel.restoreOptions
                ) {
                    Task { await viewModel.confirmRestore(pending.url) }
                } onCancel: {
                    viewModel.pendingRestoreURL = nil
                    viewModel.backupPreview = nil
                }
            }
            .alert(MR.strings.backupRestoreComplete, isPresented: $viewModel.isShowingRestoreResult) {
                Button("確定", role: .cancel) { viewModel.restoreResult = nil }
            } message: {
                if let result = viewModel.restoreResult {
                    Text(result.summary)
                }
            }
            .alert(MR.strings.backupErrorOccurred, isPresented: $viewModel.isShowingError) {
                Button("確定", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                if let msg = viewModel.errorMessage {
                    Text(msg)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressOverlay(message: viewModel.loadingMessage)
                }
            }
        }
        .task {
            viewModel.refreshBackupList()
        }
    }

    // MARK: - Sections

    private var actionsSection: some View {
        Section {
            // 建立備份
            Button {
                Task { await viewModel.createBackup() }
            } label: {
                Label(MR.strings.backupCreate, systemImage: "arrow.down.doc")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(viewModel.isLoading)

            // 還原備份（從檔案）
            Button {
                viewModel.isShowingFilePicker = true
            } label: {
                Label(MR.strings.backupRestore, systemImage: "arrow.up.doc")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(viewModel.isLoading)

        } header: {
            Text(MR.strings.backupActions)
        } footer: {
            Text(MR.strings.backupActionsDesc)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var autoBackupsSection: some View {
        Section {
            if viewModel.backupFiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.clock")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(MR.strings.backupNoBackups)
                        .font(.headline)
                    Text(MR.strings.backupNoBackupsDesc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.backupFiles) { entry in
                    BackupFileRow(entry: entry) {
                        viewModel.shareItem = ShareItem(url: entry.url)
                    } onRestore: {
                        Task { await viewModel.prepareRestore(from: entry.url) }
                    } onDelete: {
                        viewModel.deleteBackup(entry)
                    }
                }
            }
        } header: {
            HStack {
                Text(MR.strings.backupLocal)
                Spacer()
                if !viewModel.backupFiles.isEmpty {
                    Text(viewModel.backupSizeLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text(MR.strings.backupLocalFooter)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }
}

// MARK: - RestoreOptionsSheet

private struct RestoreOptionsSheet: View {
    let pendingURL: PendingRestoreURL
    let preview: BackupPreview?
    @Binding var options: BackupRestoreOptions
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                // Preview Section
                if let preview = preview {
                    Section {
                        previewRow("漫畫", value: preview.mangaCount, icon: "books.vertical")
                        previewRow("分類", value: preview.categoryCount, icon: "folder")
                        previewRow("章節", value: preview.chapterCount, icon: "list.bullet")
                        previewRow("追蹤記錄", value: preview.trackCount, icon: "chart.line.uptrend.xyaxis")
                        previewRow("閱讀歷史", value: preview.historyCount, icon: "clock")
                    } header: {
                        Text(MR.strings.backupContents)
                    } footer: {
                        Text(MR.strings.backupCreatedAt(preview.formattedCreatedAt, "\(preview.version)"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        HStack {
                            ProgressView()
                            Text(MR.strings.backupLoading)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                        }
                    }
                }

                // Options Section
                Section {
                    Toggle(isOn: $options.restoreManga) {
                        Label(MR.strings.backupMangaData, systemImage: "books.vertical")
                    }
                    Toggle(isOn: $options.restoreCategories) {
                        Label(MR.strings.backupCategories, systemImage: "folder")
                    }
                    Toggle(isOn: $options.restoreChapters) {
                        Label(MR.strings.backupChapterProgress, systemImage: "list.bullet")
                    }
                    .disabled(!options.restoreManga)
                    Toggle(isOn: $options.restoreTracks) {
                        Label(MR.strings.backupTrackingRecords, systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .disabled(!options.restoreManga)
                    Toggle(isOn: $options.restoreHistory) {
                        Label(MR.strings.backupReadingHistory, systemImage: "clock")
                    }
                    .disabled(!options.restoreManga || !options.restoreChapters)
                } header: {
                    Text(MR.strings.backupSelectItems)
                } footer: {
                    Text(MR.strings.backupSelectItemsDesc)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(MR.strings.backupRestoreOptions)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(MR.strings.actionCancel, role: .cancel) { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(MR.strings.backupStartRestore) { onConfirm() }
                        .fontWeight(.semibold)
                        .disabled(preview == nil || isNothingSelected)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var isNothingSelected: Bool {
        !options.restoreManga && !options.restoreCategories
    }

    private func previewRow(_ label: String, value: Int, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            Text("\(value)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - BackupFileRow

private struct BackupFileRow: View {
    let entry: BackupFileEntry
    let onShare: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.zipper")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(entry.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Menu {
                Button {
                    onRestore()
                } label: {
                    Label(MR.strings.backupRestoreFrom, systemImage: "arrow.clockwise")
                }
                Button {
                    onShare()
                } label: {
                    Label(MR.strings.backupShareExport, systemImage: "square.and.arrow.up")
                }
                Divider()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(MR.strings.actionDelete, systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - ProgressOverlay

private struct ProgressOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - ShareSheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - ViewModel

@MainActor
final class BackupViewModel: ObservableObject {

    // MARK: Published

    @Published var backupFiles: [BackupFileEntry] = []
    @Published var isLoading = false
    @Published var loadingMessage = "處理中…"
    @Published var isShowingFilePicker = false
    @Published var restoreResult: RestoreResultDisplay?
    @Published var isShowingRestoreResult = false
    @Published var errorMessage: String?
    @Published var isShowingError = false
    @Published var shareItem: ShareItem?

    /// 等待使用者確認的還原 URL（觸發選項 Sheet）
    @Published var pendingRestoreURL: PendingRestoreURL?
    /// 備份預覽資料
    @Published var backupPreview: BackupPreview?
    /// 使用者選擇的還原選項
    @Published var restoreOptions = BackupRestoreOptions.all

    var backupSizeLabel: String {
        AutoBackupManager.shared.formattedBackupSize
    }

    // MARK: - Actions

    func refreshBackupList() {
        backupFiles = AutoBackupManager.shared.existingBackups.map { BackupFileEntry(url: $0) }
    }

    func createBackup() async {
        loadingMessage = "建立備份中…"
        isLoading = true
        defer {
            isLoading = false
            refreshBackupList()
        }
        do {
            _ = try await AutoBackupManager.shared.performBackup()
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }

    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await prepareRestore(from: url) }
        case .failure(let error):
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }

    /// 先讀取備份預覽，再呈現還原選項 sheet。
    func prepareRestore(from url: URL) async {
        loadingMessage = "讀取備份資訊中…"
        isLoading = true
        defer { isLoading = false }

        do {
            let restorer = BackupRestorer()
            let preview = try await restorer.previewBackup(from: url)
            backupPreview = preview
            restoreOptions = .all
            pendingRestoreURL = PendingRestoreURL(url: url)
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }

    /// 使用者確認選項後，執行實際還原。
    func confirmRestore(_ url: URL) async {
        pendingRestoreURL = nil
        backupPreview = nil

        loadingMessage = "還原中…"
        isLoading = true
        defer { isLoading = false }

        do {
            let restorer = BackupRestorer()
            let result = try await restorer.restoreBackup(from: url, options: restoreOptions)
            restoreResult = RestoreResultDisplay(result: result)
            isShowingRestoreResult = true
        } catch {
            errorMessage = error.localizedDescription
            isShowingError = true
        }
    }

    func deleteBackup(_ entry: BackupFileEntry) {
        try? FileManager.default.removeItem(at: entry.url)
        refreshBackupList()
    }
}

// MARK: - Supporting Types

struct BackupFileEntry: Identifiable {
    let id = UUID()
    let url: URL
    private let attributes: [FileAttributeKey: Any]?

    init(url: URL) {
        self.url = url
        self.attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
    }

    var displayName: String { url.deletingPathExtension().lastPathComponent }

    var formattedDate: String {
        guard let date = attributes?[.modificationDate] as? Date else { return "未知日期" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "zh-TW")
        return f.string(from: date)
    }

    var formattedSize: String {
        guard let size = attributes?[.size] as? Int64 else { return "" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// 包裝 URL 使其符合 Identifiable，作為 sheet(item:) 的觸發器。
struct PendingRestoreURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct RestoreResultDisplay: Identifiable {
    let id = UUID()
    let result: BackupRestoreResult

    var summary: String {
        var lines = [
            "已還原 \(result.mangaCount) 本漫畫",
            "章節：\(result.chapterCount)",
            "分類：\(result.categoryCount)",
            "追蹤記錄：\(result.trackCount)",
        ]
        if !result.errors.isEmpty {
            lines.append("警告：\(result.errors.count) 項目發生錯誤")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - UTType Extension

extension UTType {
    /// `.shinsoubackup` 自訂檔案類型
    static let shinsouBackup = UTType(exportedAs: "com.shinsou.backup", conformingTo: .data)
    /// 向後相容：支援匯入舊的 `.mihonbackup` 檔案
    static let mihonBackupLegacy = UTType(importedAs: "com.mihon.backup", conformingTo: .data)
}
