import Foundation

struct SwiftDataGoalStore: GoalStore {
    let database: LedgerDatabase
    func fetchSnapshot() async throws -> GoalSnapshot { try await database.fetchGoals() }
    func save(_ draft: GoalDraft, id: UUID?) async throws -> FinancialGoal {
        try await database.saveGoal(draft, id: id)
    }
    func addContribution(goalID: UUID, amountText: String, date: Date, note: String) async throws -> GoalContribution {
        try await database.addGoalContribution(goalID: goalID, amountText: amountText, date: date, note: note)
    }
    func deleteContribution(id: UUID) async throws { try await database.deleteGoalContribution(id: id) }
    func deleteGoal(id: UUID) async throws { try await database.deleteGoal(id: id) }
}
