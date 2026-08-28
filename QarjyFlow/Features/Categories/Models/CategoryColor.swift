import Foundation

enum CategoryColor: String, CaseIterable, Codable, Identifiable {
    case green, blue, orange, pink, purple, teal

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
