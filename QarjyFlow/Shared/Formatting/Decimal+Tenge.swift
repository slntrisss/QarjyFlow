import Foundation

extension Decimal {
    /// Decimal plays the role of Java's BigDecimal for monetary values.
    /// Formatting is centralized in `MoneyFormatting` (cached formatter, space grouping).
    var tenge: String { MoneyFormatting.tenge(self) }
}
