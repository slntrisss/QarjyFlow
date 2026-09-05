import Foundation
import SwiftData

@Model
final class PlannedIncomeRecord {
    @Attribute(.unique) var id: UUID
    var planID: UUID
    var name: String
    var normalizedName: String
    var amountMinor: Int64

    init(id: UUID, planID: UUID, name: String, amountMinor: Int64) {
        self.id = id; self.planID = planID; self.name = name
        normalizedName = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        self.amountMinor = amountMinor
    }
}
