import Foundation

enum GoalKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case ongoing
    case target
    var id: String { rawValue }
    var title: String { self == .ongoing ? "Ongoing" : "Target amount" }
}
