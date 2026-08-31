import Foundation
import Observation

@MainActor
@Observable
final class TransactionsViewModel {
    private(set) var transactions: [TransactionItem] = []
    private(set) var categories: [CategoryItem] = []
    private(set) var hasLoaded = false
    private(set) var loadFailed = false
    var filter: CategoryKind?
    var searchText = ""
    var errorMessage: String?
    @ObservationIgnored private let store: any TransactionStore
    @ObservationIgnored private let categoryStore: any CategoryStore

    init(store: any TransactionStore, categoryStore: any CategoryStore) {
        self.store = store
        self.categoryStore = categoryStore
    }

    var visibleTransactions: [TransactionItem] {
        transactions.filter { item in
            (filter == nil || filter == item.kind) && (searchText.isEmpty ||
                item.merchant.localizedStandardContains(searchText) ||
                item.note.localizedStandardContains(searchText) ||
                (category(for: item)?.name.localizedStandardContains(searchText) ?? false))
        }
    }

    func category(for item: TransactionItem) -> CategoryItem? {
        categories.first { $0.id == item.categoryID }
    }

    func load() {
        do {
            let newCategories = try categoryStore.fetchAll()
            let newTransactions = try store.fetchAll()
            categories = newCategories
            transactions = newTransactions
            hasLoaded = true
            loadFailed = false
            errorMessage = nil
        } catch {
            loadFailed = true
            errorMessage = "Could not load your transactions. Please try again."
        }
    }

    func save(_ draft: TransactionDraft, id: UUID?) throws {
        let saved = try store.save(draft, id: id)
        transactions.removeAll { $0.id == saved.id }
        transactions.append(saved)
        transactions.sort { $0.date > $1.date }
    }

    func delete(_ item: TransactionItem) {
        do {
            try store.delete(id: item.id)
            transactions.removeAll { $0.id == item.id }
        } catch {
            errorMessage = "Could not delete this transaction. Please try again."
        }
    }
}
