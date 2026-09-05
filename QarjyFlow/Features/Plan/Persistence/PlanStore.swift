protocol PlanStore: Sendable {
    func fetch(month: PlanMonth) async throws -> MonthlyPlan?
    func save(_ plan: MonthlyPlan) async throws -> MonthlyPlan
}
