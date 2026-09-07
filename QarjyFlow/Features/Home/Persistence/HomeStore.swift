protocol HomeStore: Sendable {
    func fetch(month: PlanMonth) async throws -> HomeDataSnapshot
}
