import Foundation
import XCTest
@testable import CategoriesCore

final class GoalPersistenceTests: XCTestCase {
    private func targetDraft() -> GoalDraft {
        var draft = GoalDraft()
        draft.name = "Car"
        draft.kind = .target
        draft.targetText = "15000000"
        draft.symbol = "car.fill"
        return draft
    }

    func testGoalContributionAndPlanLinkRoundTrip() async throws {
        let database = try await LedgerDatabase.open(inMemory: true)
        let goal = try await database.saveGoal(targetDraft(), id: nil)
        _ = try await database.addGoalContribution(goalID: goal.id, amountText: "328000",
                                                   date: Date(), note: "Salary allocation")
        let group = PlanGroup(id: UUID(), name: "Future", subtitle: "",
                              symbol: "sparkles", color: .purple)
        let allocation = PlanAllocation(id: UUID(), name: goal.name, symbol: goal.symbol,
                                        groupID: group.id, categoryID: nil, goalID: goal.id,
                                        tracksContribution: true, rule: .fixed(300_000))
        let month = PlanMonth(year: 2026, month: 9)
        let plan = MonthlyPlan(id: UUID(), month: month, incomeSources: [],
                               groups: [group], allocations: [allocation])
        _ = try await database.savePlan(plan)

        let snapshot = try await database.fetchGoals()
        let loadedPlan = try await database.fetchPlan(month: month)
        XCTAssertEqual(snapshot.goals, [goal])
        XCTAssertEqual(snapshot.contributed(to: goal.id), 328_000)
        XCTAssertEqual(loadedPlan?.allocations.first?.goalID, goal.id)
    }

    func testGoalsPersistAcrossDiskReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("goals.store")
        var goalID: UUID!
        do {
            let database = try await LedgerDatabase.open(url: url)
            let goal = try await database.saveGoal(targetDraft(), id: nil)
            goalID = goal.id
            _ = try await database.addGoalContribution(goalID: goal.id, amountText: "25000",
                                                       date: Date(), note: "First deposit")
        }
        let reopened = try await LedgerDatabase.open(url: url)
        let snapshot = try await reopened.fetchGoals()
        XCTAssertEqual(snapshot.goals.first?.id, goalID)
        XCTAssertEqual(snapshot.goals.first?.targetAmount, 15_000_000)
        XCTAssertEqual(snapshot.contributed(to: goalID), 25_000)
    }
}
