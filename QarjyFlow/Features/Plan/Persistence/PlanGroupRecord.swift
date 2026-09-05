import Foundation
import SwiftData

@Model
final class PlanGroupRecord {
    @Attribute(.unique) var id: UUID
    var planID: UUID
    var name: String
    var normalizedName: String
    var subtitle: String
    var symbol: String
    var colorRawValue: String
    var sortOrder: Int

    init(group: PlanGroup, planID: UUID, sortOrder: Int) {
        id = group.id; self.planID = planID; name = group.name
        normalizedName = group.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        subtitle = group.subtitle; symbol = group.symbol; colorRawValue = group.color.rawValue
        self.sortOrder = sortOrder
    }
}
