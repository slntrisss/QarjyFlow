import Foundation
import SwiftData

@Model
final class CategoryRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var normalizedName: String
    var kindRawValue: String
    var symbol: String
    var colorRawValue: String
    var isArchived: Bool

    init(id: UUID = UUID(), draft: CategoryDraft) {
        self.id = id
        name = draft.trimmedName
        normalizedName = draft.normalizedName
        kindRawValue = draft.kind.rawValue
        symbol = draft.symbol
        colorRawValue = draft.color.rawValue
        isArchived = false
    }

    var item: CategoryItem {
        CategoryItem(
            id: id, name: name, kind: CategoryKind(rawValue: kindRawValue) ?? .expense,
            symbol: symbol, color: ThemeColor(rawValue: colorRawValue) ?? .green,
            isArchived: isArchived
        )
    }
}
