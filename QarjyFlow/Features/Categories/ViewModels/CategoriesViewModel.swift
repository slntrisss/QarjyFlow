import Foundation
import Observation
import os

@MainActor
@Observable
final class CategoriesViewModel {
    private(set) var categories: [CategoryItem] = []
    private(set) var hasLoaded = false
    private(set) var isMutating = false
    private(set) var isLoading = false
    @ObservationIgnored private var revision = 0
    var searchText = ""
    var errorMessage: String?
    @ObservationIgnored private let store: any CategoryStore

    init(store: any CategoryStore) { self.store = store }

    var visibleCategories: [CategoryItem] {
        categories.filter {
            !$0.isArchived &&
            (searchText.isEmpty || $0.name.localizedStandardContains(searchText))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func load() async {
        guard !isMutating else { return }
        revision += 1
        let request = revision
        isLoading = true
        defer { if request == revision { isLoading = false } }
        do {
            let loaded = try await store.fetchAll()
            guard request == revision, !Task.isCancelled else { return }
            categories = loaded
            hasLoaded = true
            errorMessage = nil
        } catch {
            guard request == revision, !Task.isCancelled else { return }
            AppLog.categories.error("Load failed: \(String(describing: error), privacy: .private(mask: .hash))")
            errorMessage = "Could not load your categories. Please try again."
        }
    }

    func save(_ draft: CategoryDraft, id: UUID?) async throws {
        guard !isMutating else { throw CancellationError() }
        isMutating = true
        isLoading = false
        revision += 1
        defer { isMutating = false }
        let saved = try await store.save(draft, id: id)
        replace(saved)
    }

    func delete(_ category: CategoryItem) async {
        guard !isMutating else { return }
        isMutating = true
        isLoading = false
        revision += 1
        defer { isMutating = false }
        do {
            try await store.delete(id: category.id)
            categories.removeAll { $0.id == category.id }
        } catch let error as CategoryError {
            errorMessage = error.localizedDescription
        } catch {
            AppLog.categories.error("Delete failed: \(String(describing: error), privacy: .private(mask: .hash))")
            errorMessage = "Could not delete this category. Please try again."
        }
    }

    private func replace(_ item: CategoryItem) {
        categories.removeAll { $0.id == item.id }
        categories.append(item)
    }
}
