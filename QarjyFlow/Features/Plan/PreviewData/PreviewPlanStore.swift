import Foundation

@MainActor
final class PreviewPlanStore: PlanStore {
    private var plans: [String: MonthlyPlan] = [:]
    func fetch(month: PlanMonth) throws -> MonthlyPlan? { plans[month.key] }
    func save(_ plan: MonthlyPlan) throws -> MonthlyPlan { plans[plan.month.key] = plan; return plan }
}
