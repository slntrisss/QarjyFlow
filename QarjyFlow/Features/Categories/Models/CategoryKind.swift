import Foundation

enum CategoryKind: String, CaseIterable, Codable, Identifiable {
    case expense
    case income

    var id: String { rawValue }
    var title: String { self == .expense ? "Expense" : "Income" }
}
