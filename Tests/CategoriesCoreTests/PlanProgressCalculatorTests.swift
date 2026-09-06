import Foundation
import XCTest
@testable import CategoriesCore

final class PlanProgressCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private func transaction(amount: Int64, kind: CategoryKind, categoryID: UUID,
                             date: String) -> TransactionItem {
        TransactionItem(id: UUID(), amountMinor: amount * 100, kind: kind,
                        categoryID: categoryID, date: self.date(date), merchant: "", note: "")
    }

    func testMatchesExpenseActualsByCategoryAndMonth() throws {
        let rentID = UUID(), groceriesID = UUID(), salaryID = UUID()
        let group = PlanGroup(id: UUID(), name: "Needs", subtitle: "",
                              symbol: "house.fill", color: .blue)
        let rent = PlanAllocation(id: UUID(), name: "Rent", symbol: "house.fill",
                                  groupID: group.id, categoryID: rentID,
                                  tracksContribution: false, rule: .fixed(300_000))
        let future = PlanAllocation(id: UUID(), name: "S&P 500", symbol: "chart.line.uptrend.xyaxis",
                                    groupID: group.id, categoryID: nil,
                                    tracksContribution: true, rule: .fixed(100_000))
        let plan = MonthlyPlan(id: UUID(), month: PlanMonth(year: 2026, month: 9),
                               incomeSources: [.init(id: UUID(), name: "Salary", amount: 1_000_000)],
                               groups: [group], allocations: [rent, future])
        let transactions = [
            transaction(amount: 500_000, kind: .income, categoryID: salaryID,
                        date: "2026-09-05T12:00:00Z"),
            transaction(amount: 250_000, kind: .expense, categoryID: rentID,
                        date: "2026-09-06T12:00:00Z"),
            transaction(amount: 20_000, kind: .expense, categoryID: groceriesID,
                        date: "2026-09-06T12:00:00Z"),
            transaction(amount: 50_000, kind: .expense, categoryID: rentID,
                        date: "2026-08-31T23:59:59Z")
        ]

        let result = PlanProgressCalculator().calculate(
            plan: plan, transactions: transactions, calendar: calendar
        )
        XCTAssertEqual(result.recordedIncome, 500_000)
        XCTAssertEqual(result.stillExpectedIncome, 500_000)
        XCTAssertEqual(result.unplannedSpending, 20_000)
        let rentProgress = try XCTUnwrap(result.allocations.first { $0.id == rent.id })
        XCTAssertEqual(rentProgress.planned, 300_000)
        XCTAssertEqual(rentProgress.actual, 250_000)
        XCTAssertEqual(rentProgress.remaining, 50_000)
        XCTAssertFalse(rentProgress.isOverBudget)
        XCTAssertNil(result.allocations.first { $0.id == future.id }?.actual)
    }

    func testOverspendingProducesNegativeRemaining() throws {
        let categoryID = UUID()
        let group = PlanGroup(id: UUID(), name: "Needs", subtitle: "",
                              symbol: "house.fill", color: .blue)
        let allocation = PlanAllocation(id: UUID(), name: "Rent", symbol: "house.fill",
                                        groupID: group.id, categoryID: categoryID,
                                        tracksContribution: false, rule: .fixed(300_000))
        let plan = MonthlyPlan(id: UUID(), month: PlanMonth(year: 2026, month: 9),
                               incomeSources: [], groups: [group], allocations: [allocation])
        let result = PlanProgressCalculator().calculate(
            plan: plan,
            transactions: [transaction(amount: 325_000, kind: .expense,
                                       categoryID: categoryID, date: "2026-09-06T12:00:00Z")],
            calendar: calendar
        )
        let progress = try XCTUnwrap(result.allocations.first)
        XCTAssertEqual(progress.remaining, -25_000)
        XCTAssertTrue(progress.isOverBudget)
    }
}
