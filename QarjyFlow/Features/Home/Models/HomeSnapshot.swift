import Foundation

/// Presentation data, not yet a persisted account or transaction ledger.
struct HomeSnapshot {
    let month: String
    let income: Decimal
    let saved: Decimal
    let categories: [CategorySnapshot]

    var spent: Decimal { categories.reduce(0) { $0 + $1.spent } }
    var available: Decimal { income - spent - saved }

    var overBudgetCategories: [CategorySnapshot] { categories.filter { $0.remaining < 0 } }
}
