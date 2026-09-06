import Foundation

struct GoalContribution: Identifiable, Equatable, Sendable {
    let id: UUID
    let goalID: UUID
    let amountMinor: Int64
    let date: Date
    let note: String
    var amount: Decimal { .fromMinorUnits(amountMinor) }
}
