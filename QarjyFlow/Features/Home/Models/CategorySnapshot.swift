import Foundation

struct CategorySnapshot: Identifiable {
    var id: String { name }
    let name: String
    let symbol: String
    let spent: Decimal
    let budget: Decimal

    var remaining: Decimal { budget - spent }
    var budgetFraction: Double {
        guard budget > 0 else { return 0 }
        return NSDecimalNumber(decimal: spent / budget).doubleValue
    }
}
