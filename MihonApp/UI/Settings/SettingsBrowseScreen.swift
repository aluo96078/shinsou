import SwiftUI
import MihonDomain
import MihonI18n

// MARK: - Repository row

private struct RepositoryRowView: View {
    let repo: ExtensionRepo
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "externaldrive.connected.to.line.below")
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(repo.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(repo.baseUrl)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Main view

struct SettingsBrowseScreen: View {

    @AppStorage(SettingsKeys.checkExtensionUpdates) private var checkExtensionUpdates: Bool = true
    @AppStorage(SettingsKeys.showNSFWSources)       private var showNSFW: Bool              = false

    @StateObject private var viewModel = SettingsBrowseViewModel()

    var body: some View {
        List {
            // MARK: Extensions
            Section {
                Toggle(isOn: $checkExtensionUpdates) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.browseCheckUpdates)
                        Text(MR.strings.browseCheckUpdatesDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(MR.strings.browseExtensions)
            }

            // MARK: Sources
            Section {
                Toggle(isOn: $showNSFW) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MR.strings.browseShowNsfw)
                        Text(MR.strings.browseShowNsfwDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(MR.strings.browseSources)
            } footer: {
                Text(MR.strings.browseNsfwWarning)
            }

            // MARK: Repositories
            Section {
                if viewModel.repos.isEmpty {
                    Text(MR.strings.browseNoCustomRepos)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(viewModel.repos) { repo in
                        RepositoryRowView(repo: repo) {
                            viewModel.deleteRepo(repo)
                        }
                    }
                }

                Button {
                    viewModel.newRepoUrl = ""
                    viewModel.showAddRepo = true
                } label: {
                    Label(MR.strings.browseAddRepository, systemImage: "plus")
                }
            } header: {
                Text(MR.strings.browseRepositories)
            } footer: {
                Text(MR.strings.browseRepoFooter)
            }
        }
        .navigationTitle(MR.strings.settingsBrowse)
        .navigationBarTitleDisplayMode(.inline)
        .alert(MR.strings.browseAddRepository, isPresented: $viewModel.showAddRepo) {
            TextField(MR.strings.browseRepositoryUrl, text: $viewModel.newRepoUrl)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            Button(MR.strings.commonAdd) {
                Task { await viewModel.addRepo() }
            }
            Button(MR.strings.commonCancel, role: .cancel) {}
        } message: {
            Text(MR.strings.browseRepoFooter)
        }
        .alert(MR.strings.commonError, isPresented: $viewModel.showError) {
            Button(MR.strings.commonOk, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .task {
            await viewModel.loadRepos()
        }
    }
}

// MARK: - ViewModel

@MainActor
final class SettingsBrowseViewModel: ObservableObject {
    @Published var repos: [ExtensionRepo] = []
    @Published var showAddRepo = false
    @Published var newRepoUrl = ""
    @Published var showError = false
    @Published var errorMessage = ""

    private let repoRepository: any ExtensionRepoRepository
    private let repoService: ExtensionRepoService

    init() {
        self.repoRepository = DIContainer.shared.extensionRepoRepository
        self.repoService = ExtensionRepoService()
    }

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

    func deleteRepo(_ repo: ExtensionRepo) {
        Task {
            let deleteRepo = DeleteExtensionRepo(repository: repoRepository)
            try? await deleteRepo.execute(baseUrl: repo.baseUrl)
            await loadRepos()
        }
    }

    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
    }
}

#Preview {
    NavigationStack {
        SettingsBrowseScreen()
    }
}
