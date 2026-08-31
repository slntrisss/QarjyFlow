import Foundation

enum TransactionError: LocalizedError {
    case invalidAmount, invalidCategory, archivedCategory, kindMismatch, invalidDate, textTooLong, notFound

    var errorDescription: String? {
        switch self {
        case .invalidAmount: "Enter a positive amount, up to 999,999,999,999.99 ₸, with at most two decimal places. Do not use grouping separators."
        case .invalidCategory: "Choose an existing category."
        case .archivedCategory: "Choose an active category for a new transaction."
        case .kindMismatch: "The category must match the transaction's income or expense type."
        case .invalidDate: "Choose today or an earlier date."
        case .textTooLong: "Use at most 100 characters for the merchant and 500 for the note."
        case .notFound: "This transaction no longer exists. Reload Activity."
        }
    }
}
