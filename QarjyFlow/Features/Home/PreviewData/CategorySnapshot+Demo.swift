import Foundation

/// Stable fixtures keep isolated previews repeatable, without array indexing.
extension CategorySnapshot {
    static let demoFood = CategorySnapshot(
        name: "Food", symbol: "fork.knife", spent: 164_200, budget: 187_500
    )

    static let demoEntertainment = CategorySnapshot(
        name: "Entertainment", symbol: "play.tv.fill", spent: 136_300, budget: 93_750
    )
}
