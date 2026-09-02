import Foundation

/// Parses positive KZT amounts (or two-decimal percentage input) without floating point.
enum AmountInputParsing {
    static func positiveMinorUnits(_ input: String) -> Int64? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count),
              !parts[0].isEmpty, parts[0].count <= 12,
              parts.allSatisfy({ $0.allSatisfy { $0 >= "0" && $0 <= "9" } }),
              let whole = Int64(parts[0]) else { return nil }
        var fraction: Int64 = 0
        if parts.count == 2 {
            guard (1...2).contains(parts[1].count), let value = Int64(parts[1]) else {
                return nil
            }
            fraction = parts[1].count == 1 ? value * 10 : value
        }
        let minor = whole * 100 + fraction
        guard minor > 0 else { return nil }
        return minor
    }
}
