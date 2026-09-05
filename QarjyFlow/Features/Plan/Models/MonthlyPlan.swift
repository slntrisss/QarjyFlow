import Foundation

struct MonthlyPlan: Identifiable, Equatable, Sendable {
    let id: UUID
    let month: PlanMonth
    var incomeSources: [PlannedIncomeSource]
    var groups: [PlanGroup]
    var allocations: [PlanAllocation]

    var income: Decimal { incomeSources.reduce(0) { $0 + $1.amount } }
    var allocated: Decimal { allocations.reduce(0) { $0 + $1.rule.amount(income: income) } }
    var unallocated: Decimal { income - allocated }
}
