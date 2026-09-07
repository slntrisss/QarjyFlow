import Foundation

struct CategorySpendingMetric: Identifiable, Equatable, Sendable {
    let category: CategoryItem
    let amount: Decimal
    let share: Decimal
    var id: UUID { category.id }
}
