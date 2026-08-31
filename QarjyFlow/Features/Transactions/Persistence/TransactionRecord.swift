import Foundation
import SwiftData

@Model
final class TransactionRecord {
    @Attribute(.unique) var id: UUID
    var amountMinor: Int64
    var kindRawValue: String
    var categoryID: UUID
    var date: Date
    var merchant: String
    var note: String

    init(id: UUID = UUID(), amountMinor: Int64, categoryID: UUID, draft: TransactionDraft) {
        self.id = id
        self.amountMinor = amountMinor
        self.categoryID = categoryID
        kindRawValue = draft.kind.rawValue
        date = draft.date
        merchant = draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var item: TransactionItem {
        TransactionItem(
            id: id, amountMinor: amountMinor, kind: CategoryKind(rawValue: kindRawValue) ?? .expense,
            categoryID: categoryID, date: date, merchant: merchant, note: note
        )
    }
}
