import Foundation
import SwiftData

@Model
final class PlanAllocationRecord {
    @Attribute(.unique) var id: UUID
    var planID: UUID
    var groupID: UUID
    var categoryID: UUID?
    var name: String
    var symbol: String
    var tracksContribution: Bool
    var modeRawValue: String
    var valueMinor: Int64

    init(allocation: PlanAllocation, planID: UUID) {
        id = allocation.id; self.planID = planID; groupID = allocation.groupID
        categoryID = allocation.categoryID; name = allocation.name; symbol = allocation.symbol
        tracksContribution = allocation.tracksContribution
        switch allocation.rule {
        case .fixed(let amount): modeRawValue = "fixed"; valueMinor = amount.minorUnits
        case .percentage(let percentage): modeRawValue = "percentage"; valueMinor = percentage.minorUnits
        }
    }
}
