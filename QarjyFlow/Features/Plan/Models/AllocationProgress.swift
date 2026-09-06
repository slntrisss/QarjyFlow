import Foundation

struct AllocationProgress: Identifiable, Equatable, Sendable {
    let allocation: PlanAllocation
    let planned: Decimal
    /// Nil for Future purposes because ordinary expense transactions cannot prove a contribution.
    let actual: Decimal?

    var id: UUID { allocation.id }
    var remaining: Decimal? { actual.map { planned - $0 } }
    var fractionUsed: Decimal? {
        guard let actual, planned > 0 else { return nil }
        return actual / planned
    }
    var isOverBudget: Bool { remaining.map { $0 < 0 } ?? false }
}
