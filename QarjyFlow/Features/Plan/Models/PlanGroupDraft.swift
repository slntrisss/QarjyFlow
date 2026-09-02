import Foundation

struct PlanGroupDraft: Sendable {
    var name = ""
    var subtitle = ""
    var symbol = "tag.fill"
    var color: ThemeColor = .green

    init() {}

    init(group: PlanGroup) {
        name = group.name
        subtitle = group.subtitle
        symbol = group.symbol
        color = group.color
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedSubtitle: String { subtitle.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { !trimmedName.isEmpty && trimmedName.count <= 40 && trimmedSubtitle.count <= 100 }
}
