import Foundation
import SwiftData

@Model final class FinancialGoalRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var normalizedName: String
    var kindRawValue: String
    var targetMinor: Int64?
    var symbol: String
    var colorRawValue: String

    init(goal: FinancialGoal) {
        id = goal.id; name = goal.name
        normalizedName = goal.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        kindRawValue = goal.kind.rawValue; targetMinor = goal.targetAmount?.minorUnits
        symbol = goal.symbol; colorRawValue = goal.color.rawValue
    }
}
