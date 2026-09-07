import Foundation

struct HomeDashboardCalculator: Sendable {
    func calculate(
        month: PlanMonth,
        transactions: [TransactionItem],
        plan: MonthlyPlan?,
        contributions: [GoalContribution],
        calendar: Calendar = .current
    ) -> HomeDashboardSnapshot {
        let currentTransactions = transactions.filter { month.contains($0.date, calendar: calendar) }
        let income = currentTransactions.filter { $0.kind == .income }.reduce(Decimal.zero) { $0 + $1.amount }
        let expenses = currentTransactions.filter { $0.kind == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
        let contributed = contributions
            .filter { month.contains($0.date, calendar: calendar) }
            .reduce(Decimal.zero) { $0 + $1.amount }

        let previousMonth = offset(month, by: -1, calendar: calendar)
        let previousExpenses = transactions
            .filter { $0.kind == .expense && previousMonth.contains($0.date, calendar: calendar) }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let expenseChange = previousExpenses > 0
            ? ((expenses - previousExpenses) / previousExpenses) * 100
            : nil

        let planProgress = plan.map {
            PlanProgressCalculator().calculate(
                plan: $0, transactions: transactions, contributions: contributions, calendar: calendar
            )
        }
        let planned = planProgress?.allocations.reduce(Decimal.zero) { $0 + $1.planned } ?? 0
        let actual = planProgress?.allocations.compactMap(\.actual).reduce(Decimal.zero, +) ?? 0
        let overspend = planProgress?.allocations
            .filter { $0.isOverBudget }
            .max { abs($0.remaining ?? 0) < abs($1.remaining ?? 0) }

        return HomeDashboardSnapshot(
            recordedIncome: income,
            recordedExpenses: expenses,
            goalContributions: contributed,
            calculatedRemaining: income - expenses - contributed,
            savingsRate: income > 0 ? contributed / income * 100 : nil,
            previousMonthExpenses: previousExpenses,
            expenseChangeRate: expenseChange,
            plannedAmount: planned,
            actualAgainstPlan: actual,
            largestOverspend: overspend
        )
    }

    private func offset(_ month: PlanMonth, by value: Int, calendar: Calendar) -> PlanMonth {
        var components = DateComponents(); components.year = month.year; components.month = month.month
        let date = calendar.date(from: components) ?? Date()
        let shifted = calendar.date(byAdding: .month, value: value, to: date) ?? date
        return PlanMonth(year: calendar.component(.year, from: shifted),
                         month: calendar.component(.month, from: shifted))
    }
}
