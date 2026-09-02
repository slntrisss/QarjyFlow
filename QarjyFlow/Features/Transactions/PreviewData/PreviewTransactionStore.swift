import Foundation

@MainActor
final class PreviewTransactionStore: TransactionStore {
    private let repository: TransactionRepository
    private let categories: PreviewCategoryStore
    init(repository: TransactionRepository, categories: PreviewCategoryStore) {
        self.repository = repository
        self.categories = categories
    }

    func fetchSnapshot() throws -> LedgerSnapshot {
        try LedgerSnapshot(categories: categories.fetchAll(), transactions: repository.fetchAll())
    }

    func fetchAll() throws -> [TransactionItem] { try repository.fetchAll() }
    func save(_ draft: TransactionDraft, id: UUID?) throws -> TransactionItem { try repository.save(draft, id: id) }
    func delete(id: UUID) throws { try repository.delete(id: id) }
}
