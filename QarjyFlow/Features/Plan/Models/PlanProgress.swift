import Foundation

struct PlanProgress: Equatable, Sendable {
    let expectedIncome: Decimal
    let recordedIncome: Decimal
    let allocations: [AllocationProgress]
    let unplannedSpending: Decimal

    var stillExpectedIncome: Decimal { expectedIncome - recordedIncome }
    var plannedExpenses: Decimal {
        allocations.filter { $0.actual != nil }.reduce(0) { $0 + $1.planned }
    }
    var recordedPlannedSpending: Decimal {
        allocations.compactMap(\.actual).reduce(0, +)
    }
}
