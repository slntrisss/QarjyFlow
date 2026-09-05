import Foundation

/// A persisted monthly intent linked to an expense category or a standalone Future purpose.
struct PlanAllocation: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let symbol: String
    var groupID: UUID
    let categoryID: UUID?
    let tracksContribution: Bool
    var rule: PlanAllocationRule
}
