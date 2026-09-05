import Foundation

enum PlanDefaults {
    static func groups() -> [PlanGroup] {
        [
            .init(id: UUID(), name: "Needs", subtitle: "Everyday essentials", symbol: "house.fill", color: .blue),
            .init(id: UUID(), name: "Future", subtitle: "Savings and investments", symbol: "chart.line.uptrend.xyaxis", color: .green),
            .init(id: UUID(), name: "Lifestyle", subtitle: "Things you enjoy", symbol: "sparkles", color: .purple),
            .init(id: UUID(), name: "Free", subtitle: "An intentional flexible allocation", symbol: "leaf.fill", color: .orange)
        ]
    }
}
