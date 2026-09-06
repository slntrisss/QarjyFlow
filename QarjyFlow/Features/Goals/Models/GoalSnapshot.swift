import Foundation

struct GoalSnapshot: Equatable, Sendable {
    let goals: [FinancialGoal]
    let contributions: [GoalContribution]

    func contributed(to goalID: UUID) -> Decimal {
        contributions.filter { $0.goalID == goalID }.reduce(0) { $0 + $1.amount }
    }
}
