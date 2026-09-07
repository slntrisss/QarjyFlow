import Foundation

struct HomeDashboardSnapshot: Equatable, Sendable {
    let recordedIncome: Decimal
    let recordedExpenses: Decimal
    let goalContributions: Decimal
    let calculatedRemaining: Decimal
    let savingsRate: Decimal?
    let previousMonthExpenses: Decimal
    let expenseChangeRate: Decimal?
    let plannedAmount: Decimal
    let actualAgainstPlan: Decimal
    let largestOverspend: AllocationProgress?

    var hasPlan: Bool { plannedAmount > 0 }
}
