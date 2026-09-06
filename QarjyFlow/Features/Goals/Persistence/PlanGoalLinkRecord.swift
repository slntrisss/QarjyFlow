import Foundation
import SwiftData

@Model final class PlanGoalLinkRecord {
    @Attribute(.unique) var allocationID: UUID
    var goalID: UUID
    init(allocationID: UUID, goalID: UUID) {
        self.allocationID = allocationID; self.goalID = goalID
    }
}
