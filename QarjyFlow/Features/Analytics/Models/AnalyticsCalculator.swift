import Foundation

struct AnalyticsCalculator: Sendable {
    func calculate(data: HomeDataSnapshot, month: PlanMonth,
                   now: Date = Date(), calendar: Calendar = .current) -> AnalyticsSnapshot {
        let dashboard = HomeDashboardCalculator().calculate(
            month: month, transactions: data.transactions, plan: data.plan,
            contributions: data.contributions, calendar: calendar
        )
        let monthExpenses = data.transactions.filter {
            $0.kind == .expense && month.contains($0.date, calendar: calendar)
        }
        let categoryByID = Dictionary(data.categories.map { ($0.id, $0) }) { first, _ in first }
        let totals = Dictionary(grouping: monthExpenses, by: \.categoryID)
            .mapValues { $0.reduce(Decimal.zero) { $0 + $1.amount } }
        let categoryMetrics = totals.compactMap { id, amount -> CategorySpendingMetric? in
            guard let category = categoryByID[id] else { return nil }
            let share = dashboard.recordedExpenses > 0 ? amount / dashboard.recordedExpenses * 100 : 0
            return CategorySpendingMetric(category: category, amount: amount, share: share)
        }.sorted { $0.amount > $1.amount }
        let dayCount = elapsedDays(in: month, through: now, calendar: calendar)
        let progress = data.plan.map {
            PlanProgressCalculator().calculate(
                plan: $0, transactions: data.transactions,
                contributions: data.contributions, calendar: calendar
            ).allocations
        } ?? []

        return AnalyticsSnapshot(
            recordedIncome: dashboard.recordedIncome,
            totalSpent: dashboard.recordedExpenses,
            goalContributions: dashboard.goalContributions,
            calculatedRemaining: dashboard.calculatedRemaining,
            savingsRate: dashboard.savingsRate,
            previousMonthSpent: dashboard.previousMonthExpenses,
            spendingChangeRate: dashboard.expenseChangeRate,
            averageDailySpend: dayCount > 0 ? dashboard.recordedExpenses / Decimal(dayCount) : 0,
            categories: categoryMetrics,
            planProgress: progress
        )
    }

    private func elapsedDays(in month: PlanMonth, through date: Date, calendar: Calendar) -> Int {
        var components = DateComponents(); components.year = month.year; components.month = month.month; components.day = 1
        guard let start = calendar.date(from: components), month.contains(date, calendar: calendar) else {
            return calendar.range(of: .day, in: .month, for: calendar.date(from: components) ?? date)?.count ?? 1
        }
        return max(1, (calendar.dateComponents([.day], from: start, to: date).day ?? 0) + 1)
    }
}
