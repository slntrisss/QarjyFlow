import Foundation
import SwiftData

@Model
final class MonthlyPlanRecord {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var monthKey: String
    var year: Int
    var month: Int

    init(id: UUID = UUID(), month: PlanMonth) {
        self.id = id; monthKey = month.key; year = month.year; self.month = month.month
    }
}
