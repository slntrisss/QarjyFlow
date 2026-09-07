import Foundation

struct AnalyticsSnapshot: Equatable, Sendable {
    let recordedIncome: Decimal
    let totalSpent: Decimal
    let goalContributions: Decimal
    let calculatedRemaining: Decimal
    let savingsRate: Decimal?
    let previousMonthSpent: Decimal
    let spendingChangeRate: Decimal?
    let averageDailySpend: Decimal
    let categories: [CategorySpendingMetric]
    let planProgress: [AllocationProgress]

    var overspentAllocations: [AllocationProgress] {
        planProgress.filter(\.isOverBudget).sorted {
            abs($0.remaining ?? 0) > abs($1.remaining ?? 0)
        }
    }
}
