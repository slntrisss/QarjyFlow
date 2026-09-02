import Foundation

/// Prototype rule: percentages use expected income, rounded to the nearest tiyn.
/// This rounding policy is provisional until the persisted Plan rules are agreed.
enum PlanAllocationRule: Equatable, Sendable {
    case fixed(Decimal)
    case percentage(Decimal)

    func amount(income: Decimal) -> Decimal {
        switch self {
        case .fixed(let amount): return amount
        case .percentage(let percent):
            var value = income * percent / 100
            var rounded = Decimal()
            NSDecimalRound(&rounded, &value, 2, .plain)
            return rounded
        }
    }
}
