import Foundation

actor PreviewGoalStore: GoalStore {
    private var snapshot = GoalSnapshot(goals: [], contributions: [])
    func fetchSnapshot() async throws -> GoalSnapshot { snapshot }
    func save(_ draft: GoalDraft, id: UUID?) async throws -> FinancialGoal {
        guard !draft.trimmedName.isEmpty, draft.kind == .ongoing || draft.targetAmount != nil else {
            throw GoalError.invalidGoal
        }
        let goal = FinancialGoal(id: id ?? UUID(), name: draft.trimmedName, kind: draft.kind,
                                 targetAmount: draft.kind == .target ? draft.targetAmount : nil,
                                 symbol: draft.symbol, color: draft.color)
        var goals = snapshot.goals.filter { $0.id != goal.id }; goals.append(goal)
        snapshot = GoalSnapshot(goals: goals, contributions: snapshot.contributions)
        return goal
    }
    func addContribution(goalID: UUID, amountText: String, date: Date, note: String) async throws -> GoalContribution {
        guard let minor = AmountInputParsing.positiveMinorUnits(amountText) else { throw GoalError.invalidContribution }
        let value = GoalContribution(id: UUID(), goalID: goalID, amountMinor: minor, date: date, note: note)
        snapshot = GoalSnapshot(goals: snapshot.goals, contributions: snapshot.contributions + [value])
        return value
    }
    func deleteContribution(id: UUID) async throws {
        snapshot = GoalSnapshot(goals: snapshot.goals,
                                contributions: snapshot.contributions.filter { $0.id != id })
    }
    func deleteGoal(id: UUID) async throws {
        guard snapshot.goals.contains(where: { $0.id == id }) else { throw GoalError.notFound }
        snapshot = GoalSnapshot(goals: snapshot.goals.filter { $0.id != id },
                                contributions: snapshot.contributions.filter { $0.goalID != id })
    }
}
