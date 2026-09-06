import Foundation

struct PlanProgressCalculator: Sendable {
    func calculate(plan: MonthlyPlan, transactions: [TransactionItem],
                   calendar: Calendar = .current) -> PlanProgress {
        let monthTransactions = transactions.filter { plan.month.contains($0.date, calendar: calendar) }
        let recordedIncome = monthTransactions.filter { $0.kind == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let expenseTransactions = monthTransactions.filter { $0.kind == .expense }
        let plannedCategoryIDs = Set(plan.allocations.compactMap(\.categoryID))

        let progress = plan.allocations.map { allocation in
            let planned = allocation.rule.amount(income: plan.income)
            guard let categoryID = allocation.categoryID else {
                return AllocationProgress(allocation: allocation, planned: planned, actual: nil)
            }
            let actual = expenseTransactions.filter { $0.categoryID == categoryID }
                .reduce(Decimal.zero) { $0 + $1.amount }
            return AllocationProgress(allocation: allocation, planned: planned, actual: actual)
        }
        let unplanned = expenseTransactions.filter { !plannedCategoryIDs.contains($0.categoryID) }
            .reduce(Decimal.zero) { $0 + $1.amount }

        return PlanProgress(expectedIncome: plan.income, recordedIncome: recordedIncome,
                            allocations: progress, unplannedSpending: unplanned)
    }
}
