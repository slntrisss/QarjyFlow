import Foundation
import SwiftData

@Model final class GoalContributionRecord {
    @Attribute(.unique) var id: UUID
    var goalID: UUID
    var amountMinor: Int64
    var date: Date
    var note: String

    init(_ value: GoalContribution) {
        id = value.id; goalID = value.goalID; amountMinor = value.amountMinor
        date = value.date; note = value.note
    }
}
