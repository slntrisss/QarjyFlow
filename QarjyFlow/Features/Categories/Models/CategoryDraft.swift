import Foundation

/// Editing a draft never changes a stored category until Save succeeds.
struct CategoryDraft {
    var name = ""
    var kind: CategoryKind = .expense
    var symbol = "tag.fill"
    var color: CategoryColor = .green

    static let symbols = [
        "tag.fill", "house.fill", "fork.knife", "bus.fill", "bag.fill",
        "play.tv.fill", "heart.fill", "book.fill", "airplane",
        "gift.fill", "briefcase.fill", "banknote.fill"
    ]

    init() {}

    init(category: CategoryItem) {
        name = category.name
        kind = category.kind
        symbol = category.symbol
        color = category.color
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var normalizedName: String {
        trimmedName.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    func validate() throws {
        guard !trimmedName.isEmpty else { throw CategoryError.emptyName }
        guard trimmedName.count <= 60 else { throw CategoryError.nameTooLong }
        guard !trimmedName.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            throw CategoryError.invalidName
        }
        guard Self.symbols.contains(symbol) else { throw CategoryError.invalidSymbol }
    }
}
