import SwiftUI
import MihonDomain

/// A sheet that lets the user pick one or more categories to assign to a set of manga.
/// Used in two contexts:
/// 1. Library selection mode → move selected manga to categories
/// 2. MangaDetail → assign categories when adding to library
struct CategoryPickerSheet: View {
    let categoryRepository: CategoryRepository
    let mangaIds: [Int64]
    var onComplete: (() -> Void)? = nil

    @State private var categories: [MihonDomain.Category] = []
    @State private var selectedCategoryIds: Set<Int64> = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if categories.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No categories yet")
                            .font(.headline)
                        Text("Create categories from Library settings first.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    categoryList
                }
            }
            .navigationTitle("Set Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        saveCategories()
                    }
                    .disabled(categories.isEmpty)
                }
            }
        }
        .task { await loadData() }
    }

    private var categoryList: some View {
        List {
            // Default category (id=0) is always available
            categoryRow(MihonDomain.Category(id: 0, name: "Default", sort: -1, flags: 0))

            ForEach(categories) { category in
                categoryRow(category)
            }
        }
        .listStyle(.plain)
    }

    private func categoryRow(_ category: MihonDomain.Category) -> some View {
        Button {
            if category.id == 0 {
                // Selecting Default → clear all others
                selectedCategoryIds = [0]
            } else if selectedCategoryIds.contains(category.id) {
                selectedCategoryIds.remove(category.id)
                // If nothing selected, fall back to Default
                if selectedCategoryIds.isEmpty || selectedCategoryIds == [0] {
                    selectedCategoryIds = [0]
                }
            } else {
                // Selecting a real category → remove Default
                selectedCategoryIds.remove(0)
                selectedCategoryIds.insert(category.id)
            }
        } label: {
            HStack {
                Image(systemName: selectedCategoryIds.contains(category.id)
                      ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedCategoryIds.contains(category.id)
                                    ? Color.accentColor : .secondary)

                Text(category.name)
                    .foregroundStyle(.primary)

                Spacer()
            }
        }
    }

    private func loadData() async {
        isLoading = true
        do {
            let all = try await categoryRepository.getAll()
            categories = all.filter { !$0.isSystemCategory }.sorted { $0.sort < $1.sort }

            // Pre-select current categories for all manga (intersection)
            if let firstId = mangaIds.first {
                let currentCats = try await categoryRepository.getCategoriesForManga(mangaId: firstId)
                selectedCategoryIds = Set(currentCats.map(\.id))

                // For multiple manga, keep only common categories
                for mangaId in mangaIds.dropFirst() {
                    let cats = try await categoryRepository.getCategoriesForManga(mangaId: mangaId)
                    selectedCategoryIds.formIntersection(Set(cats.map(\.id)))
                }
            }

            // If no categories assigned, default to "Default" (id=0)
            if selectedCategoryIds.isEmpty {
                selectedCategoryIds.insert(0)
            }
        } catch {
            print("CategoryPickerSheet load error: \(error)")
        }
        isLoading = false
    }

    private func saveCategories() {
        // Filter out Default (id=0) — it's a virtual category.
        // If only Default is selected, we clear all manga_category records
        // so the SQL COALESCE falls back to 0.
        let realCategoryIds = selectedCategoryIds.filter { $0 > 0 }
        Task {
            for mangaId in mangaIds {
                do {
                    try await categoryRepository.setMangaCategories(
                        mangaId: mangaId,
                        categoryIds: Array(realCategoryIds)
                    )
                } catch {
                    print("Failed to set categories for manga \(mangaId): \(error)")
                }
            }
            onComplete?()
            dismiss()
        }
    }
}
