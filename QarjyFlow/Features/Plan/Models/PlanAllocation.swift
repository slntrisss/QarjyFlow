import Foundation

/// Presentation data only. Persisted allocations will reference category/purpose IDs.
struct PlanAllocation: Identifiable, Sendable {
    let id: UUID
    let name: String
    let symbol: String
    var groupID: UUID
    let tracksContribution: Bool
    var rule: PlanAllocationRule
}
