import Foundation

enum HomeScenarioPreviewData {
    static var rich: HomeDataSnapshot {
        let salaryID = UUID(), rentID = UUID(), foodID = UUID(), transportID = UUID()
        let categories = [
            CategoryItem(id: salaryID, name: "Salary", kind: .income,
                         symbol: "banknote.fill", color: .green, isArchived: false),
            CategoryItem(id: rentID, name: "Housing", kind: .expense,
                         symbol: "house.fill", color: .blue, isArchived: false),
            CategoryItem(id: foodID, name: "Food", kind: .expense,
                         symbol: "fork.knife", color: .orange, isArchived: false),
            CategoryItem(id: transportID, name: "Transport", kind: .expense,
                         symbol: "bus.fill", color: .purple, isArchived: false)
        ]
        let month = PlanMonth()
        let goalID = UUID()
        let group = PlanGroup(id: UUID(), name: "Needs", subtitle: "Essentials",
                              symbol: "house.fill", color: .blue)
        let future = PlanGroup(id: UUID(), name: "Future", subtitle: "Savings and investments",
                               symbol: "sparkles", color: .purple)
        let plan = MonthlyPlan(
            id: UUID(), month: month,
            incomeSources: [.init(id: UUID(), name: "Salary", amount: 800_000)],
            groups: [group, future],
            allocations: [
                PlanAllocation(id: UUID(), name: "Housing", symbol: "house.fill", groupID: group.id,
                               categoryID: rentID, tracksContribution: false, rule: .fixed(280_000)),
                PlanAllocation(id: UUID(), name: "Food", symbol: "fork.knife", groupID: group.id,
                               categoryID: foodID, tracksContribution: false, rule: .fixed(120_000)),
                PlanAllocation(id: UUID(), name: "S&P 500", symbol: "chart.line.uptrend.xyaxis",
                               groupID: future.id, categoryID: nil, goalID: goalID,
                               tracksContribution: true, rule: .fixed(150_000))
            ]
        )
        let transactions = [
            transaction(800_000, .income, salaryID, currentDay: 2, merchant: "Employer"),
            transaction(300_000, .expense, rentID, currentDay: 3, merchant: "Landlord"),
            transaction(82_000, .expense, foodID, currentDay: 5, merchant: "Magnum"),
            transaction(45_000, .expense, transportID, currentDay: 7, merchant: "Transport"),
            transaction(65_000, .expense, foodID, monthOffset: -1, currentDay: 8, merchant: "Groceries"),
            transaction(35_000, .expense, transportID, monthOffset: -1, currentDay: 12, merchant: "Transport")
        ].sorted { $0.date > $1.date }
        let contributions = [
            GoalContribution(id: UUID(), goalID: goalID, amountMinor: 150_000_00,
                             date: date(monthOffset: 0, day: 6), note: "Monthly investment")
        ]
        return HomeDataSnapshot(transactions: transactions, categories: categories,
                                plan: plan, contributions: contributions)
    }

    private static func transaction(_ amount: Int64, _ kind: CategoryKind, _ categoryID: UUID,
                                    monthOffset: Int = 0, currentDay: Int, merchant: String) -> TransactionItem {
        TransactionItem(id: UUID(), amountMinor: amount * 100, kind: kind, categoryID: categoryID,
                        date: date(monthOffset: monthOffset, day: currentDay), merchant: merchant, note: "")
    }

    private static func date(monthOffset: Int, day: Int) -> Date {
        let calendar = Calendar.current
        let shifted = calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
        var components = calendar.dateComponents([.year, .month], from: shifted)
        components.day = min(day, calendar.range(of: .day, in: .month, for: shifted)?.count ?? day)
        components.hour = 12
        return calendar.date(from: components) ?? shifted
    }
}
