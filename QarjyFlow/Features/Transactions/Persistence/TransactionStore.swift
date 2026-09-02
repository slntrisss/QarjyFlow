import Foundation

protocol TransactionStore: Sendable {
    func fetchSnapshot() async throws -> LedgerSnapshot
    func fetchAll() async throws -> [TransactionItem]
    func save(_ draft: TransactionDraft, id: UUID?) async throws -> TransactionItem
    func delete(id: UUID) async throws
}
