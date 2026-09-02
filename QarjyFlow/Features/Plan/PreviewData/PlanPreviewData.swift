import Foundation

enum PlanPreviewData {
    static let incomeSources: [PlannedIncomeSource] = [
        .init(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, name: "Salary", amount: 700_000),
        .init(id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!, name: "Freelance", amount: 100_000)
    ]
    static var income: Decimal { incomeSources.reduce(0) { $0 + $1.amount } }
    static let needsID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let futureID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    static let lifestyleID = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
    static let freeID = UUID(uuidString: "10000000-0000-0000-0000-000000000004")!

    static let groups: [PlanGroup] = [
        .init(id: needsID, name: "Needs", subtitle: "Everyday essentials", symbol: "house.fill", color: .blue),
        .init(id: futureID, name: "Future", subtitle: "Savings and investments", symbol: "chart.line.uptrend.xyaxis", color: .green),
        .init(id: lifestyleID, name: "Lifestyle", subtitle: "Things you enjoy", symbol: "sparkles", color: .purple),
        .init(id: freeID, name: "Free", subtitle: "An intentional flexible allocation", symbol: "leaf.fill", color: .orange)
    ]

    static let allocations: [PlanAllocation] = [
        .init(id: UUID(), name: "Rent", symbol: "house.fill", groupID: needsID, tracksContribution: false, rule: .fixed(250_000)),
        .init(id: UUID(), name: "Groceries", symbol: "basket.fill", groupID: needsID, tracksContribution: false, rule: .fixed(100_000)),
        .init(id: UUID(), name: "Transport", symbol: "bus.fill", groupID: needsID, tracksContribution: false, rule: .fixed(40_000)),
        .init(id: UUID(), name: "Investments", symbol: "chart.line.uptrend.xyaxis", groupID: futureID, tracksContribution: true, rule: .percentage(30)),
        .init(id: UUID(), name: "Emergency fund", symbol: "shield.fill", groupID: futureID, tracksContribution: true, rule: .percentage(5)),
        .init(id: UUID(), name: "Entertainment", symbol: "sparkles", groupID: lifestyleID, tracksContribution: false, rule: .fixed(50_000)),
        .init(id: UUID(), name: "Subscriptions", symbol: "play.rectangle.fill", groupID: lifestyleID, tracksContribution: false, rule: .fixed(15_000)),
        .init(id: UUID(), name: "Flexible spending", symbol: "leaf.fill", groupID: freeID, tracksContribution: false, rule: .fixed(35_000))
    ]
}
