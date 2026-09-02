import Foundation

struct TransactionDraft: Sendable {
    var amountText = ""
    var kind: CategoryKind = .expense
    var categoryID: UUID?
    var date = Date()
    var merchant = ""
    var note = ""

    init() {}

    init(transaction: TransactionItem) {
        amountText = NSDecimalNumber(decimal: transaction.amount).stringValue
        kind = transaction.kind
        categoryID = transaction.categoryID
        date = transaction.date
        merchant = transaction.merchant
        note = transaction.note
    }

    /// KZT has two fractional digits. Parse directly to tiyn, never via Double.
    func amountMinor() throws -> Int64 {
        guard let amount = AmountInputParsing.positiveMinorUnits(amountText) else {
            throw TransactionError.invalidAmount
        }
        return amount
    }

    func validate(now: Date = Date(), calendar: Calendar = .current) throws {
        _ = try amountMinor()
        guard categoryID != nil else { throw TransactionError.invalidCategory }
        guard date.timeIntervalSinceReferenceDate.isFinite,
              calendar.startOfDay(for: date) <= calendar.startOfDay(for: now) else {
            throw TransactionError.invalidDate
        }
        guard merchant.count <= 100, note.count <= 500 else { throw TransactionError.textTooLong }
    }
}
