import Foundation

/// Single source of truth for displaying tenge amounts.
///
/// - Caches one `NumberFormatter` instead of allocating one per call (this used
///   to run once per row, per body pass, during scrolling).
/// - Uses space grouping so display matches `AmountInputFormatting` (`1 875 000`)
///   rather than the old locale comma grouping (`1,875,000`).
enum MoneyFormatting {
    private static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "\u{202F}" // narrow no-break space, same family the input field accepts
        formatter.groupingSize = 3
        formatter.decimalSeparator = "."
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// e.g. `1 875 000 ₸`, `87.44 ₸`, `-20 000 ₸`. Returns `— ₸` only if formatting fails.
    static func tenge(_ value: Decimal) -> String {
        let number = formatter.string(from: NSDecimalNumber(decimal: value)) ?? "—"
        return "\(number) ₸"
    }
}
