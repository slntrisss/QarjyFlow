import Foundation
import Observation

@MainActor
@Observable
final class TransactionsViewModel {
    private(set) var transactions: [TransactionItem] = []
    private(set) var categories: [CategoryItem] = []
    private(set) var hasLoaded = false
    private(set) var isMutating = false
    @ObservationIgnored private var revision = 0
    private(set) var loadFailed = false
    var filter: CategoryKind?
    var searchText = ""
    var errorMessage: String?
    @ObservationIgnored private let store: any TransactionStore

    init(store: any TransactionStore, initialSnapshot: LedgerSnapshot? = nil) {
        if let initialSnapshot {
            transactions = initialSnapshot.transactions
            categories = initialSnapshot.categories
            hasLoaded = true
        }
        self.store = store
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

    func load() async {
        guard !isMutating else { return }
        revision += 1
        let request = revision
        do {
            let snapshot = try await store.fetchSnapshot()
            guard request == revision, !Task.isCancelled else { return }
            categories = snapshot.categories
            transactions = snapshot.transactions
            hasLoaded = true
            loadFailed = false
            errorMessage = nil
        } catch {
            guard request == revision, !Task.isCancelled else { return }
            loadFailed = true
            errorMessage = "Could not load your transactions. Please try again."
        }
    }

    func save(_ draft: TransactionDraft, id: UUID?) async throws {
        guard !isMutating else { throw CancellationError() }
        isMutating = true
        revision += 1
        defer { isMutating = false }
        let saved = try await store.save(draft, id: id)
        transactions.removeAll { $0.id == saved.id }
        transactions.append(saved)
        transactions.sort { $0.date > $1.date }
    }

    func delete(_ item: TransactionItem) async {
        guard !isMutating else { return }
        isMutating = true
        revision += 1
        defer { isMutating = false }
        do {
            try await store.delete(id: item.id)
            transactions.removeAll { $0.id == item.id }
        } catch {
            errorMessage = "Could not delete this transaction. Please try again."
        }
    }
}
