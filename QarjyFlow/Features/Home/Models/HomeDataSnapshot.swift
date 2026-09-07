import Foundation

struct HomeDataSnapshot: Equatable, Sendable {
    let transactions: [TransactionItem]
    let categories: [CategoryItem]
    let plan: MonthlyPlan?
    let contributions: [GoalContribution]
}
