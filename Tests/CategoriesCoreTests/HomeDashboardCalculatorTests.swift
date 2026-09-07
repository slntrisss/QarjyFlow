import Foundation
import XCTest
@testable import CategoriesCore

final class HomeDashboardCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    private func transaction(_ amount: Int64, kind: CategoryKind, categoryID: UUID, date: String) -> TransactionItem {
        TransactionItem(id: UUID(), amountMinor: amount * 100, kind: kind, categoryID: categoryID,
                        date: self.date(date), merchant: "", note: "")
    }

    func testCombinesTransactionsPlanAndGoalsWithoutCountingPlansAsMoneyMovement() throws {
        let salaryID = UUID(), rentID = UUID(), goalID = UUID()
        let group = PlanGroup(id: UUID(), name: "Needs", subtitle: "", symbol: "house", color: .blue)
        let rent = PlanAllocation(id: UUID(), name: "Rent", symbol: "house", groupID: group.id,
                                  categoryID: rentID, tracksContribution: false, rule: .fixed(300_000))
        let investing = PlanAllocation(id: UUID(), name: "S&P 500", symbol: "chart.line.uptrend.xyaxis",
                                       groupID: group.id, categoryID: nil, goalID: goalID,
                                       tracksContribution: true, rule: .fixed(100_000))
        let plan = MonthlyPlan(id: UUID(), month: PlanMonth(year: 2026, month: 9),
                               incomeSources: [.init(id: UUID(), name: "Salary", amount: 800_000)],
                               groups: [group], allocations: [rent, investing])
        let transactions = [
            transaction(800_000, kind: .income, categoryID: salaryID, date: "2026-09-02T12:00:00Z"),
            transaction(325_000, kind: .expense, categoryID: rentID, date: "2026-09-03T12:00:00Z"),
            transaction(200_000, kind: .expense, categoryID: rentID, date: "2026-08-03T12:00:00Z")
        ]
        let contributions = [GoalContribution(id: UUID(), goalID: goalID, amountMinor: 120_000_00,
                                              date: date("2026-09-04T12:00:00Z"), note: "")]

        let result = HomeDashboardCalculator().calculate(
            month: plan.month, transactions: transactions, plan: plan,
            contributions: contributions, calendar: calendar
        )

        XCTAssertEqual(result.recordedIncome, 800_000)
        XCTAssertEqual(result.recordedExpenses, 325_000)
        XCTAssertEqual(result.goalContributions, 120_000)
        XCTAssertEqual(result.calculatedRemaining, 355_000)
        XCTAssertEqual(result.savingsRate, 15)
        XCTAssertEqual(result.previousMonthExpenses, 200_000)
        XCTAssertEqual(result.expenseChangeRate, Decimal(string: "62.5"))
        XCTAssertEqual(result.plannedAmount, 400_000)
        XCTAssertEqual(result.actualAgainstPlan, 445_000)
        XCTAssertEqual(result.largestOverspend?.allocation.id, rent.id)
        XCTAssertEqual(result.largestOverspend?.remaining, -25_000)
    }

    func testRatesAreUnavailableWithoutRecordedIncomeOrPreviousSpending() {
        let result = HomeDashboardCalculator().calculate(
            month: PlanMonth(year: 2026, month: 9), transactions: [], plan: nil,
            contributions: [], calendar: calendar
        )
        XCTAssertNil(result.savingsRate)
        XCTAssertNil(result.expenseChangeRate)
        XCTAssertEqual(result.calculatedRemaining, 0)
        XCTAssertFalse(result.hasPlan)
    }

    func testHomeDatabaseQueryExcludesTransactionsOlderThanPreviousMonth() async throws {
        let database = try await LedgerDatabase.open(inMemory: true)
        var categoryDraft = CategoryDraft(); categoryDraft.name = "Food"
        let category = try await database.saveCategory(categoryDraft, id: nil)

        for (amount, timestamp) in [("100", "2026-09-05T12:00:00Z"),
                                    ("200", "2026-08-05T12:00:00Z"),
                                    ("300", "2026-07-05T12:00:00Z")] {
            var draft = TransactionDraft(); draft.amountText = amount
            draft.categoryID = category.id; draft.date = date(timestamp)
            _ = try await database.saveTransaction(draft, id: nil)
        }

        let data = try await database.fetchHomeData(
            month: PlanMonth(year: 2026, month: 9), calendar: calendar
        )
        XCTAssertEqual(data.transactions.map(\.amount), [100, 200])
        XCTAssertEqual(data.categories.map(\.id), [category.id])
    }
}
