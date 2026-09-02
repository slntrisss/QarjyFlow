import Foundation

/// Expected income is a planning input. It never creates an Activity transaction.
struct PlannedIncomeSource: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var amount: Decimal
}
