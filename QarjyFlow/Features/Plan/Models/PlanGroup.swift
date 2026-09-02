import Foundation

/// A user-defined presentation section inside a monthly plan.
struct PlanGroup: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var subtitle: String
    var symbol: String
    var color: ThemeColor
}
