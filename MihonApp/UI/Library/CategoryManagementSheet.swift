import SwiftUI
import MihonDomain
import MihonI18n

// MARK: - CategoryManagementSheet
//
// Presents all user-created categories in a reorderable list.
// • Drag-to-reorder: persists new sort order via CategoryRepository.
// • Add: shows an inline text field / alert to name a new category.
// • Edit (rename): taps a category to rename it in-place.
// • Delete: swipe-to-delete with confirmation.
//
// Usage:
//   .sheet(isPresented: $showCategoryManagement) {
//       CategoryManagementSheet(categoryRepository: DIContainer.shared.categoryRepository)
//           .presentationDetents([.medium, .large])
//   }

struct CategoryManagementSheet: View {
    // MARK: - Dependencies

    let categoryRepository: CategoryRepository

    // MARK: - Local State

    @State private var categories: [MihonDomain.Category] = []
    @State private var isLoading = true
    @State private var showAddAlert = false
    @State private var newCategoryName = ""
    @State private var editingCategory: MihonDomain.Category? = nil
    @State private var editedName = ""
    @State private var errorMessage: String? = nil

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if categories.isEmpty {
                    emptyState
                } else {
                    categoryList
                }
            }
            .navigationTitle(MR.strings.libraryManageCategories)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            // Add category alert
            .alert(MR.strings.libraryNewCategory, isPresented: $showAddAlert) {
                TextField(MR.strings.libraryCategoryName, text: $newCategoryName)
                    .autocorrectionDisabled()
                Button(MR.strings.commonAdd) { addCategory() }
                Button(MR.strings.commonCancel, role: .cancel) { newCategoryName = "" }
            } message: {
                Text(MR.strings.libraryEnterCategoryName)
            }
            // Rename category alert
            .alert(MR.strings.libraryRenameCategory, isPresented: Binding(
                get: { editingCategory != nil },
                set: { if !$0 { editingCategory = nil } }
            )) {
                TextField(MR.strings.libraryNewName, text: $editedName)
                    .autocorrectionDisabled()
                Button(MR.strings.commonSave) { saveEdit() }
                Button(MR.strings.commonCancel, role: .cancel) { editingCategory = nil }
            } message: {
                if let cat = editingCategory {
                    Text("Renaming \"\(cat.name)\"")
                }
            }
            // Error banner
            .safeAreaInset(edge: .bottom) {
                if let msg = errorMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .onAppear {
                            Task {
                                try? await Task.sleep(for: .seconds(3))
                                errorMessage = nil
                            }
                        }
                }
            }
        }
        .task { await loadCategories() }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text(MR.strings.libraryNoCategories)
                .font(.title3.weight(.semibold))
            Text(MR.strings.libraryNoCategoriesDesc)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Category List

    private var categoryList: some View {
        List {
            ForEach(categories) { category in
                HStack(spacing: 12) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.tertiary)

                    Text(category.name)
                        .font(.body)

                    Spacer()

                    // Rename button
                    Button {
                        editedName = category.name
                        editingCategory = category
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                .contentShape(Rectangle())
            }
            .onMove(perform: moveCategories)
            .onDelete(perform: deleteCategories)
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active)) // always show drag handles
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            EditButton()
        }
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                Button {
                    newCategoryName = ""
                    showAddAlert = true
                } label: {
                    Image(systemName: "plus")
                }

                Button(MR.strings.commonDone) { dismiss() }
            }
        }
    }

    // MARK: - Data Loading

    private func loadCategories() async {
        isLoading = true
        do {
            let all = try await categoryRepository.getAll()
            // Exclude the synthetic "Default" category (id == 0)
            categories = all.filter { !$0.isSystemCategory }.sorted { $0.sort < $1.sort }
        } catch {
            errorMessage = "Failed to load categories: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Add

    private func addCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        newCategoryName = ""
        Task {
            do {
                let nextSort = (categories.map(\.sort).max() ?? -1) + 1
                let newCat = Category(id: -1, name: name, sort: nextSort, flags: 0)
                let newId = try await categoryRepository.insert(category: newCat)
                categories.append(Category(id: newId, name: name, sort: nextSort, flags: 0))
            } catch {
                errorMessage = "Failed to create category: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Rename / Edit

    private func saveEdit() {
        guard let target = editingCategory else { return }
        let name = editedName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name != target.name else {
            editingCategory = nil
            return
        }
        editingCategory = nil
        Task {
            do {
                let updated = Category(id: target.id, name: name, sort: target.sort, flags: target.flags)
                try await categoryRepository.update(category: updated)
                if let idx = categories.firstIndex(where: { $0.id == target.id }) {
                    categories[idx] = updated
                }
            } catch {
                errorMessage = "Failed to rename category: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Delete

    private func deleteCategories(at offsets: IndexSet) {
        let toDelete = offsets.map { categories[$0] }
        categories.remove(atOffsets: offsets)
        Task {
            for cat in toDelete {
                do {
                    try await categoryRepository.delete(categoryId: cat.id)
                } catch {
                    errorMessage = "Failed to delete \"\(cat.name)\": \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Reorder

    private func moveCategories(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        // Re-assign sort indices to reflect new order, then persist.
        let reindexed = categories.enumerated().map { offset, cat in
            MihonDomain.Category(id: cat.id, name: cat.name, sort: offset, flags: cat.flags)
        }
        categories = reindexed
        persistOrder(reindexed)
    }

    private func persistOrder(_ ordered: [MihonDomain.Category]) {
        Task {
            for cat in ordered {
                do {
                    try await categoryRepository.update(category: cat)
                } catch {
                    errorMessage = "Failed to save order: \(error.localizedDescription)"
                }
            }
        }
    }
}
