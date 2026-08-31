import Foundation

struct TransactionDraft {
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
        let text = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count),
              !parts[0].isEmpty, parts[0].count <= 12,
              parts.allSatisfy({ $0.allSatisfy { $0 >= "0" && $0 <= "9" } }),
              let whole = Int64(parts[0]) else { throw TransactionError.invalidAmount }
        var fraction: Int64 = 0
        if parts.count == 2 {
            guard (1...2).contains(parts[1].count), let value = Int64(parts[1]) else {
                throw TransactionError.invalidAmount
            }
            fraction = parts[1].count == 1 ? value * 10 : value
        }
        let minor = whole * 100 + fraction
        guard minor > 0 else { throw TransactionError.invalidAmount }
        return minor
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
