import Foundation

enum ThemeColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case green, blue, orange, pink, purple, teal

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
