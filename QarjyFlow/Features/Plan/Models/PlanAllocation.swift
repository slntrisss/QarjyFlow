import Foundation

/// A persisted monthly intent linked to an expense category or a standalone Future purpose.
struct PlanAllocation: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let symbol: String
    var groupID: UUID
    let categoryID: UUID?
    let goalID: UUID?
    let tracksContribution: Bool
    var rule: PlanAllocationRule

    init(id: UUID, name: String, symbol: String, groupID: UUID,
         categoryID: UUID?, goalID: UUID? = nil, tracksContribution: Bool,
         rule: PlanAllocationRule) {
        self.id = id; self.name = name; self.symbol = symbol; self.groupID = groupID
        self.categoryID = categoryID; self.goalID = goalID
        self.tracksContribution = tracksContribution; self.rule = rule
    }
}
