import Foundation
import XCTest
@testable import CategoriesCore

final class AnalyticsCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func item(_ amount: Int64, category: UUID, date value: String) -> TransactionItem {
        TransactionItem(id: UUID(), amountMinor: amount * 100, kind: .expense, categoryID: category,
                        date: date(value), merchant: "", note: "")
    }

    func testRanksCategoriesAndCalculatesDailyAndMonthlyComparison() throws {
        let foodID = UUID(), transportID = UUID()
        let food = CategoryItem(id: foodID, name: "Food", kind: .expense,
                                symbol: "fork.knife", color: .orange, isArchived: false)
        let transport = CategoryItem(id: transportID, name: "Transport", kind: .expense,
                                     symbol: "bus", color: .blue, isArchived: false)
        let data = HomeDataSnapshot(
            transactions: [
                item(300_000, category: foodID, date: "2026-09-02T12:00:00Z"),
                item(100_000, category: transportID, date: "2026-09-05T12:00:00Z"),
                item(200_000, category: foodID, date: "2026-08-05T12:00:00Z")
            ],
            categories: [food, transport], plan: nil, contributions: []
        )
        let result = AnalyticsCalculator().calculate(
            data: data, month: PlanMonth(year: 2026, month: 9),
            now: date("2026-09-10T12:00:00Z"), calendar: calendar
        )

        XCTAssertEqual(result.totalSpent, 400_000)
        XCTAssertEqual(result.previousMonthSpent, 200_000)
        XCTAssertEqual(result.spendingChangeRate, 100)
        XCTAssertEqual(result.averageDailySpend, 40_000)
        XCTAssertEqual(result.categories.map(\.category.id), [foodID, transportID])
        XCTAssertEqual(result.categories.map(\.share), [75, 25])
    }
}
