import Foundation
import Observation

@MainActor @Observable
final class AnalyticsViewModel {
    let month: PlanMonth
    private(set) var snapshot: AnalyticsSnapshot?
    private(set) var isLoading = false
    var errorMessage: String?
    @ObservationIgnored private let store: any HomeStore

    init(store: any HomeStore, month: PlanMonth = PlanMonth()) {
        self.store = store; self.month = month
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let data = try await store.fetch(month: month)
            snapshot = AnalyticsCalculator().calculate(data: data, month: month)
            errorMessage = nil
        } catch {
            errorMessage = "Could not load analytics. Your saved data is unchanged."
        }
    }
}
