import Foundation

struct GoalDraft: Sendable {
    var name = ""
    var kind: GoalKind = .ongoing
    var targetText = ""
    var symbol = "target"
    var color: ThemeColor = .blue

    init() {}
    init(goal: FinancialGoal) {
        name = goal.name; kind = goal.kind; symbol = goal.symbol; color = goal.color
        targetText = goal.targetAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
    }
    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var targetAmount: Decimal? {
        guard let minor = AmountInputParsing.positiveMinorUnits(targetText) else { return nil }
        return .fromMinorUnits(minor)
    }
}
