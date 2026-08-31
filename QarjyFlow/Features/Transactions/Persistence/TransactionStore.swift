import Foundation

@MainActor
protocol TransactionStore {
    func fetchAll() throws -> [TransactionItem]
    func save(_ draft: TransactionDraft, id: UUID?) throws -> TransactionItem
    func delete(id: UUID) throws
}
