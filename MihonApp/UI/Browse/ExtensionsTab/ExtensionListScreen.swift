import SwiftUI
import Combine
import NukeUI
import MihonSourceAPI
import MihonDomain
import MihonI18n

// MARK: - ExtensionListContent

/// Embeddable extension list content (without its own NavigationStack).
/// Used inside BrowseScreen's shared NavigationStack.
struct ExtensionListContent: View {
    @StateObject private var viewModel = ExtensionListViewModel()

    var body: some View {
        List {
            // Has Update
            if !viewModel.updateAvailable.isEmpty {
                Section {
                    HStack {
                        Text(MR.strings.browseHasUpdate)
                        Spacer()
                        Button(MR.strings.browseUpdateAll) {
                            viewModel.updateAll()
                        }
                        .font(.subheadline)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    ForEach(viewModel.updateAvailable) { ext in
                        ExtensionRowView(
                            ext: ext,
                            onAction: { viewModel.performAction(ext) },
                            onSettings: {
                                viewModel.selectedExtension = ext
                            }
                        )
                    }
                }
            }

            // Installed
            if !viewModel.installedExtensions.isEmpty {
                Section(MR.strings.browseInstalled) {
                    ForEach(viewModel.installedExtensions) { ext in
                        ExtensionRowView(
                            ext: ext,
                            onAction: { viewModel.performAction(ext) },
                            onSettings: {
                                viewModel.selectedExtension = ext
                            }
                        )
                    }
                }
            }

            // Available
            Section(MR.strings.browseAvailable) {
                if viewModel.isRefreshing && viewModel.availableExtensions.isEmpty {
                    ProgressView()
                } else if viewModel.availableExtensions.isEmpty {
                    Text(MR.strings.browseNoExtensions)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.availableExtensions) { ext in
                        ExtensionRowView(
                            ext: ext,
                            onAction: { viewModel.performAction(ext) },
                            onSettings: nil
                        )
                    }
                }
            }

            // Repositories
            Section(MR.strings.browseRepositories) {
                if viewModel.repos.isEmpty {
                    Text(MR.strings.browseNoCustomRepos)
                        .foregroundStyle(.secondary)
                }

                ForEach(viewModel.repos) { repo in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(repo.name)
                            .font(.body)
                        Text(repo.baseUrl)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    viewModel.deleteRepos(at: offsets)
                }

                Button {
                    viewModel.showAddRepo = true
                } label: {
                    Label(MR.strings.browseAddRepository, systemImage: "plus")
                }
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .navigationDestination(for: ExtensionModel.self) { ext in
            ExtensionDetailScreen(extension: ext)
        }
        .alert(MR.strings.browseAddRepository, isPresented: $viewModel.showAddRepo) {
            TextField(MR.strings.browseRepositoryUrl, text: $viewModel.newRepoUrl)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(MR.strings.commonAdd) {
                Task { await viewModel.addRepo() }
            }
            Button(MR.strings.commonCancel, role: .cancel) {
                viewModel.newRepoUrl = ""
            }
        } message: {
            Text(MR.strings.browseRepoFooter)
        }
        .alert(MR.strings.commonError, isPresented: $viewModel.showError) {
            Button(MR.strings.commonOk, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(item: $viewModel.selectedExtension) { ext in
            NavigationStack {
                ExtensionDetailScreen(extension: ext)
            }
        }
        .task {
            await viewModel.initialLoad()
        }
    }
}

// MARK: - Extension Row

private struct ExtensionRowView: View {
    let ext: ExtensionModel
    let onAction: () -> Void
    let onSettings: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Extension icon from repo or favicon
            LazyImage(url: ext.iconUrl) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(4)
                } else {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(width: 40, height: 40)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(ext.displayName)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(Locale.current.localizedString(forLanguageCode: ext.lang) ?? ext.lang.uppercased())
                        .font(.caption2)

                    Text("v\(ext.displayVersion)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if ext.nsfw {
                        Text("18+")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .cornerRadius(3)
                    }
                }
            }

            Spacer()

            // Settings gear (for installed / has-update)
            if let onSettings, ext.state == .installed || ext.state != .available {
                if case .installed = ext.state {
                    Button { onSettings() } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            actionButton
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch ext.state {
        case .available:
            Button { onAction() } label: {
                Image(systemName: "arrow.down.to.line")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)

        case .installed:
            EmptyView()

        case .hasUpdate:
            HStack(spacing: 12) {
                if let onSettings {
                    Button { onSettings() } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Button { onAction() } label: {
                    Image(systemName: "arrow.down.to.line")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }

        case .installing:
            ProgressView()
                .controlSize(.small)
        }
    }
}

// MARK: - ExtensionListViewModel

@MainActor
final class ExtensionListViewModel: ObservableObject {
    @Published var repos: [ExtensionRepo] = []
    @Published var isRefreshing = false
    @Published var showAddRepo = false
    @Published var newRepoUrl = ""
    @Published var searchText = ""
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var selectedExtension: ExtensionModel?

    private let extensionManager = ExtensionManager.shared
    private let langStore = LanguageFilterStore.shared
    private let repoRepository: any ExtensionRepoRepository
    private let repoService: ExtensionRepoService
    private var hasLoaded = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.repoRepository = DIContainer.shared.extensionRepoRepository
        self.repoService = ExtensionRepoService()

        // Forward ExtensionManager changes to trigger SwiftUI updates
        extensionManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Forward LanguageFilterStore changes
        langStore.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Filtered lists

    var installedExtensions: [ExtensionModel] {
        extensionManager.extensions.filter { ext in
            ext.state == .installed && matchesSearch(ext)
        }
    }

    var updateAvailable: [ExtensionModel] {
        extensionManager.extensions.filter { ext in
            if case .hasUpdate = ext.state { return matchesSearch(ext) }
            return false
        }
    }

    var availableExtensions: [ExtensionModel] {
        extensionManager.extensions.filter { ext in
            ext.state == .available && matchesFilter(ext)
        }
    }

    /// All unique languages present in extensions (for the filter sheet).
    var availableLanguages: [String] {
        Array(Set(extensionManager.extensions.map(\.lang)))
    }

    private func matchesFilter(_ ext: ExtensionModel) -> Bool {
        matchesLanguage(ext) && matchesSearch(ext)
    }

    private func matchesLanguage(_ ext: ExtensionModel) -> Bool {
        langStore.isEnabled(ext.lang)
    }

    private func matchesSearch(_ ext: ExtensionModel) -> Bool {
        guard !searchText.isEmpty else { return true }
        return ext.displayName.localizedCaseInsensitiveContains(searchText)
            || ext.lang.localizedCaseInsensitiveContains(searchText)
            || ext.pkg.localizedCaseInsensitiveContains(searchText)
    }

    // MARK: - Initial load

    func initialLoad() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await loadRepos()
        await refresh()
    }

    // MARK: - Refresh

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        await extensionManager.refreshAllRepos(repos: repos)
    }

    // MARK: - Repos

    func loadRepos() async {
        do {
            repos = try await repoRepository.getAll()
        } catch {
            showErrorAlert(error.localizedDescription)
        }
    }

    func addRepo() async {
        let createRepo = CreateExtensionRepo(
            repository: repoRepository,
            service: repoService
        )
        let result = await createRepo.execute(indexUrl: newRepoUrl)
        newRepoUrl = ""

        switch result {
        case .success:
            await loadRepos()
            await refresh()
        case .invalidUrl:
            showErrorAlert(MR.strings.browseInvalidUrl)
        case .repoAlreadyExists:
            showErrorAlert(MR.strings.browseRepoExists)
        case .duplicateFingerprint(let existing, _):
            showErrorAlert("Duplicate signing key: \(existing.name)")
        case .error(let msg):
            showErrorAlert(msg)
        }
    }

    func deleteRepos(at offsets: IndexSet) {
        let toDelete = offsets.map { repos[$0] }
        Task {
            for repo in toDelete {
                let deleteRepo = DeleteExtensionRepo(repository: repoRepository)
                try? await deleteRepo.execute(baseUrl: repo.baseUrl)
            }
            await loadRepos()
            await refresh()
        }
    }

    // MARK: - Extension actions

    func updateAll() {
        let toUpdate = updateAvailable
        Task {
            for ext in toUpdate {
                do {
                    try await extensionManager.updateExtension(ext)
                } catch {
                    showErrorAlert("\(ext.name): \(error.localizedDescription)")
                }
            }
        }
    }

    func performAction(_ ext: ExtensionModel) {
        Task {
            do {
                switch ext.state {
                case .available:
                    try await extensionManager.installExtension(ext)
                case .hasUpdate:
                    try await extensionManager.updateExtension(ext)
                case .installed:
                    extensionManager.uninstallExtension(ext)
                case .installing:
                    break
                }
            } catch {
                showErrorAlert(error.localizedDescription)
            }
        }
    }

    // MARK: - Helpers

    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
    }
}
