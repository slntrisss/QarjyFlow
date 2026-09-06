import Foundation

protocol GoalStore: Sendable {
    func fetchSnapshot() async throws -> GoalSnapshot
    func save(_ draft: GoalDraft, id: UUID?) async throws -> FinancialGoal
    func addContribution(goalID: UUID, amountText: String, date: Date, note: String) async throws -> GoalContribution
    func deleteContribution(id: UUID) async throws
    func deleteGoal(id: UUID) async throws
}
