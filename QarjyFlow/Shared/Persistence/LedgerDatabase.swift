import Foundation

/// A single serial worker protects category/transaction invariants together.
/// Contexts and SwiftData records stay inside this actor; only value types leave it.
actor LedgerDatabase {
    private let categories: CategoryRepository
    private let transactions: TransactionRepository

    private init(inMemory: Bool, url: URL?) throws {
        let container = try AppDatabase.makeContainer(inMemory: inMemory, url: url)
        categories = CategoryRepository(container: container)
        transactions = TransactionRepository(container: container)
    }

    static func open(inMemory: Bool = false, url: URL? = nil) async throws -> LedgerDatabase {
        // Container initialization may migrate/open disk data. Do not inherit the UI executor.
        try await Task.detached {
            try LedgerDatabase(inMemory: inMemory, url: url)
        }.value
    }

    func fetchCategories() throws -> [CategoryItem] { try categories.fetchAll() }
    func fetchTransactions() throws -> [TransactionItem] { try transactions.fetchAll() }
    func fetchSnapshot() throws -> LedgerSnapshot {
        // No suspension between reads: a concurrent delete/save cannot split the snapshot.
        try LedgerSnapshot(categories: categories.fetchAll(), transactions: transactions.fetchAll())
    }
    func saveCategory(_ draft: CategoryDraft, id: UUID?) throws -> CategoryItem {
        try categories.save(draft, id: id)
    }
    func setArchived(_ archived: Bool, id: UUID) throws -> CategoryItem {
        try categories.setArchived(archived, id: id)
    }
    func deleteCategory(id: UUID) throws { try categories.delete(id: id) }
    func saveTransaction(_ draft: TransactionDraft, id: UUID?) throws -> TransactionItem {
        try transactions.save(draft, id: id)
    }
    func deleteTransaction(id: UUID) throws { try transactions.delete(id: id) }
}
