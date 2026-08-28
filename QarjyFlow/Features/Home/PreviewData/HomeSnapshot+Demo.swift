import Foundation

extension HomeSnapshot {
    static let demo = HomeSnapshot(
        month: "August 2026", income: 1_875_000, saved: 468_750,
        categories: [
            .init(name: "Housing", symbol: "house.fill", spent: 280_000, budget: 281_250),
            .demoFood,
            .init(name: "Transport", symbol: "bus.fill", spent: 72_400, budget: 187_500),
            .demoEntertainment,
            .init(name: "Shopping", symbol: "bag.fill", spent: 54_000, budget: 93_750),
            .init(name: "Other", symbol: "square.grid.2x2.fill", spent: 334_500, budget: 375_000)
        ]
    )
}
