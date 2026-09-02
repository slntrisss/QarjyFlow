import Foundation

struct SwiftDataTransactionStore: TransactionStore {
    let database: LedgerDatabase

    func fetchSnapshot() async throws -> LedgerSnapshot { try await database.fetchSnapshot() }

    func fetchAll() async throws -> [TransactionItem] { try await database.fetchTransactions() }
    func save(_ draft: TransactionDraft, id: UUID?) async throws -> TransactionItem { try await database.saveTransaction(draft, id: id) }
    func delete(id: UUID) async throws { try await database.deleteTransaction(id: id) }
}
