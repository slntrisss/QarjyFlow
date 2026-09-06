import Foundation
import Observation

@MainActor @Observable
final class GoalsViewModel {
    private(set) var goals: [FinancialGoal] = []
    private(set) var contributions: [GoalContribution] = []
    private(set) var isLoading = false
    var errorMessage: String?
    @ObservationIgnored private let store: any GoalStore

    init(store: any GoalStore) { self.store = store }

    func load() async {
        guard !isLoading else { return }
        isLoading = true; defer { isLoading = false }
        do { apply(try await store.fetchSnapshot()); errorMessage = nil }
        catch { errorMessage = "Could not load goals." }
    }

    func save(_ draft: GoalDraft, id: UUID?) async -> String? {
        do { _ = try await store.save(draft, id: id); await load(); return nil }
        catch let error as GoalError { return error.localizedDescription }
        catch { return "Could not save this goal." }
    }

    func contribute(goalID: UUID, amountText: String, date: Date, note: String) async -> String? {
        do {
            _ = try await store.addContribution(goalID: goalID, amountText: amountText, date: date, note: note)
            await load(); return nil
        } catch let error as GoalError { return error.localizedDescription }
        catch { return "Could not save this contribution." }
    }

    func total(for goalID: UUID) -> Decimal {
        contributions.filter { $0.goalID == goalID }.reduce(0) { $0 + $1.amount }
    }

    func delete(_ goal: FinancialGoal) async {
        do { try await store.deleteGoal(id: goal.id); await load(); errorMessage = nil }
        catch let error as GoalError { errorMessage = error.localizedDescription }
        catch { errorMessage = "Could not delete this goal." }
    }

    private func apply(_ snapshot: GoalSnapshot) {
        goals = snapshot.goals; contributions = snapshot.contributions
    }
}
