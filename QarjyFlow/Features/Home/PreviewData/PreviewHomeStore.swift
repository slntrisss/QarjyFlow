actor PreviewHomeStore: HomeStore {
    private let snapshot: HomeDataSnapshot

    init(snapshot: HomeDataSnapshot = HomeDataSnapshot(
        transactions: [], categories: [], plan: nil, contributions: []
    )) {
        self.snapshot = snapshot
    }

    func fetch(month: PlanMonth) async throws -> HomeDataSnapshot { snapshot }
}
