import Foundation
import Observation
import os

@MainActor
@Observable
final class PlanViewModel {
    let month: PlanMonth
    private(set) var planID: UUID?
    private(set) var incomeSources: [PlannedIncomeSource]
    private(set) var groups: [PlanGroup]
    private(set) var allocations: [PlanAllocation]
    private(set) var hasLoaded: Bool
    private(set) var isSaving = false
    var errorMessage: String?
    @ObservationIgnored private let store: (any PlanStore)?

    init(store: (any PlanStore)? = nil, month: PlanMonth = PlanMonth(),
         initialPlan: MonthlyPlan? = nil) {
        self.store = store
        // No fallback to sample data: production must pass a real store; previews
        // and tests pass an explicit `initialPlan` fixture.
        self.month = initialPlan?.month ?? month
        planID = initialPlan?.id
        incomeSources = initialPlan?.incomeSources ?? []
        groups = initialPlan?.groups ?? []
        allocations = initialPlan?.allocations ?? []
        hasLoaded = store == nil
    }

    var income: Decimal { incomeSources.reduce(0) { $0 + $1.amount } }
    var allocated: Decimal { allocations.reduce(0) { $0 + $1.rule.amount(income: income) } }
    var hasPlan: Bool { planID != nil }
    var currentPlan: MonthlyPlan? { value }

    func load() async {
        guard let store else { return }
        do {
            apply(try await store.fetch(month: month))
            hasLoaded = true
            errorMessage = nil
        } catch {
            AppLog.plan.error("Load failed: \(String(describing: error), privacy: .private(mask: .hash))")
            hasLoaded = true
            errorMessage = "Could not load this monthly plan. Please try again."
        }
    }

    func createPlan() async {
        guard !hasPlan else { return }
        planID = UUID(); groups = PlanDefaults.groups()
        await persistOrReport(fallback: { self.apply(nil) },
                              fallbackMessage: "Could not create this monthly plan.")
    }

    func saveIncome(_ draft: PlannedIncomeDraft, id: UUID?) async -> String? {
        guard draft.isValid, let amount = draft.amount else {
            return "Enter a source name up to 60 characters and a positive amount."
        }
        guard !incomeSources.contains(where: {
            $0.id != id && $0.name.compare(draft.trimmedName,
                options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else { return "An expected income source with this name already exists." }
        let previous = incomeSources
        let source = PlannedIncomeSource(id: id ?? UUID(), name: draft.trimmedName, amount: amount)
        incomeSources.removeAll { $0.id == source.id }; incomeSources.append(source)
        if await persist(fallback: { self.incomeSources = previous }) != nil {
            return "Could not save this expected income. Your previous plan is unchanged."
        }
        return nil
    }

    func deleteIncome(id: UUID) async {
        let previous = incomeSources
        incomeSources.removeAll { $0.id == id }
        await persistOrReport(fallback: { self.incomeSources = previous },
                              fallbackMessage: "Could not delete this expected income.")
    }

    func updateAllocation(id: UUID, rule: PlanAllocationRule, groupID: UUID) async {
        guard groups.contains(where: { $0.id == groupID }),
              let index = allocations.firstIndex(where: { $0.id == id }) else { return }
        let previous = allocations
        allocations[index].rule = rule; allocations[index].groupID = groupID
        await persistOrReport(fallback: { self.allocations = previous },
                              fallbackMessage: "Could not update this allocation.")
    }

    func addAllocation(_ allocation: PlanAllocation) async -> String? {
        guard groups.contains(where: { $0.id == allocation.groupID }) else {
            return "Choose a valid Plan section."
        }
        if let categoryID = allocation.categoryID,
           allocations.contains(where: { $0.categoryID == categoryID }) {
            return "This category already has an allocation in the monthly plan."
        }
        let previous = allocations
        allocations.append(allocation)
        if await persist(fallback: { self.allocations = previous }) != nil {
            return "Could not save this allocation. Your previous plan is unchanged."
        }
        return nil
    }

    func saveGroup(_ draft: PlanGroupDraft, id: UUID?) async -> String? {
        guard draft.isValid else {
            return "Enter a section name up to 40 characters and a description up to 100 characters."
        }
        guard !groups.contains(where: {
            $0.id != id && $0.name.compare(draft.trimmedName,
                options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }) else { return "A Plan section with this name already exists." }
        let previous = groups
        let group = PlanGroup(id: id ?? UUID(), name: draft.trimmedName,
                              subtitle: draft.trimmedSubtitle, symbol: draft.symbol, color: draft.color)
        if let index = groups.firstIndex(where: { $0.id == group.id }) { groups[index] = group }
        else { groups.append(group) }
        if await persist(fallback: { self.groups = previous }) != nil {
            return "Could not save this Plan section. Your previous plan is unchanged."
        }
        return nil
    }

    func moveGroups(from source: IndexSet, to destination: Int) async {
        let previous = groups
        // `Array.move(fromOffsets:toOffset:)` ships with SwiftUI, which this
        // non-UI type does not import; this is the same relocation `onMove` performs.
        let moving = source.sorted().map { groups[$0] }
        var remaining = groups.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertionIndex = destination - source.filter { $0 < destination }.count
        remaining.insert(contentsOf: moving, at: min(max(insertionIndex, 0), remaining.count))
        groups = remaining
        await persistOrReport(fallback: { self.groups = previous }, fallbackMessage: "Could not reorder sections.")
    }

    func deleteGroups(ids: Set<UUID>) async {
        let previousGroups = groups, previousAllocations = allocations
        groups.removeAll { ids.contains($0.id) }
        allocations.removeAll { ids.contains($0.groupID) }
        await persistOrReport(fallback: { self.groups = previousGroups; self.allocations = previousAllocations },
                              fallbackMessage: "Could not delete these sections.")
    }

    func deleteAllocation(id: UUID) async {
        let previous = allocations
        allocations.removeAll { $0.id == id }
        await persistOrReport(fallback: { self.allocations = previous },
                              fallbackMessage: "Could not delete this allocation.")
    }

    func allocatedAmount(inGroupIDs ids: Set<UUID>) -> Decimal {
        allocations.filter { ids.contains($0.groupID) }.reduce(0) { $0 + $1.rule.amount(income: income) }
    }

    private var value: MonthlyPlan? {
        guard let planID else { return nil }
        return MonthlyPlan(id: planID, month: month, incomeSources: incomeSources,
                           groups: groups, allocations: allocations)
    }

    private func persist(fallback: () -> Void) async -> Error? {
        guard let store, let value else { return nil }
        guard !isSaving else { fallback(); return CancellationError() }
        isSaving = true; defer { isSaving = false }
        do { apply(try await store.save(value)); return nil }
        catch {
            AppLog.plan.error("Persist failed: \(String(describing: error), privacy: .private(mask: .hash))")
            fallback(); return error
        }
    }

    private func persistOrReport(fallback: @escaping () -> Void = {}, fallbackMessage: String) async {
        if await persist(fallback: fallback) != nil { errorMessage = fallbackMessage }
    }

    private func apply(_ plan: MonthlyPlan?) {
        planID = plan?.id; incomeSources = plan?.incomeSources ?? []
        groups = plan?.groups ?? []; allocations = plan?.allocations ?? []
    }
}
