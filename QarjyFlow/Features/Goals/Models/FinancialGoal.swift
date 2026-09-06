import Foundation

struct FinancialGoal: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var kind: GoalKind
    var targetAmount: Decimal?
    var symbol: String
    var color: ThemeColor
}
