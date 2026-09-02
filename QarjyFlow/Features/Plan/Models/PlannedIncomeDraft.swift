import Foundation

struct PlannedIncomeDraft: Sendable {
    var name = ""
    var amountText = ""

    init() {}

    init(source: PlannedIncomeSource) {
        name = source.name
        amountText = NSDecimalNumber(decimal: source.amount).stringValue
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var amount: Decimal? {
        guard let minor = AmountInputParsing.positiveMinorUnits(amountText) else { return nil }
        return Decimal(minor) / 100
    }
    var isValid: Bool { !trimmedName.isEmpty && trimmedName.count <= 60 && amount != nil }
}
