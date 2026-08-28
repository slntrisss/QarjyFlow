import Foundation

extension Decimal {
    /// Decimal plays the role of Java's BigDecimal for monetary values.
    var tenge: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return "\(formatter.string(from: NSDecimalNumber(decimal: self)) ?? "—") ₸"
    }
}
