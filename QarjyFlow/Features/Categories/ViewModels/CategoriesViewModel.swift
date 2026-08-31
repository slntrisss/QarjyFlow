import Foundation
import Observation

@MainActor
@Observable
final class CategoriesViewModel {
    private(set) var categories: [CategoryItem] = []
    private(set) var hasLoaded = false
    var searchText = ""
    var showArchived = false
    var errorMessage: String?
    @ObservationIgnored private let store: any CategoryStore

    init(store: any CategoryStore) { self.store = store }

    var visibleCategories: [CategoryItem] {
        categories.filter {
            $0.isArchived == showArchived &&
            (searchText.isEmpty || $0.name.localizedStandardContains(searchText))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func load() {
        do {
            categories = try store.fetchAll()
            hasLoaded = true
            errorMessage = nil
        } catch {
            errorMessage = "Could not load your categories. Please try again."
        }
    }

    func save(_ draft: CategoryDraft, id: UUID?) throws {
        let saved = try store.save(draft, id: id)
        replace(saved)
    }

    func setArchived(_ archived: Bool, category: CategoryItem) {
        do {
            replace(try store.setArchived(archived, id: category.id))
        } catch {
            errorMessage = "Could not update this category. Please try again."
        }
    }

    func delete(_ category: CategoryItem) {
        do {
            try store.delete(id: category.id)
            categories.removeAll { $0.id == category.id }
        } catch let error as CategoryError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Could not delete this category. Please try again."
        }
    }

    private func replace(_ item: CategoryItem) {
        categories.removeAll { $0.id == item.id }
        categories.append(item)
    }
}
