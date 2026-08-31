import Foundation

struct TransactionItem: Identifiable, Equatable {
    let id: UUID
    let amountMinor: Int64
    let kind: CategoryKind
    let categoryID: UUID
    let date: Date
    let merchant: String
    let note: String

    var amount: Decimal { Decimal(amountMinor) / 100 }
}
