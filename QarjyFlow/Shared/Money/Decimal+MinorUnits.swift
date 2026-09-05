import Foundation

extension Decimal {
    var minorUnits: Int64 { NSDecimalNumber(decimal: self * 100).int64Value }
    static func fromMinorUnits(_ value: Int64) -> Decimal { Decimal(value) / 100 }
}
