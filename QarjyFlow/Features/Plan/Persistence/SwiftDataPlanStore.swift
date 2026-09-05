struct SwiftDataPlanStore: PlanStore {
    let database: LedgerDatabase
    func fetch(month: PlanMonth) async throws -> MonthlyPlan? { try await database.fetchPlan(month: month) }
    func save(_ plan: MonthlyPlan) async throws -> MonthlyPlan { try await database.savePlan(plan) }
}
