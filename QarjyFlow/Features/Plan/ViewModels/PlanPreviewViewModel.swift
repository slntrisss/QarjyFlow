import Foundation
import Observation

/// An interactive design fixture, intentionally disconnected from persistence.
@MainActor
@Observable
final class PlanPreviewViewModel {
    private(set) var incomeSources = PlanPreviewData.incomeSources
    var income: Decimal { incomeSources.reduce(0) { $0 + $1.amount } }
    private(set) var groups = PlanPreviewData.groups
    private(set) var allocations = PlanPreviewData.allocations
    var errorMessage: String?

    var allocated: Decimal { allocations.reduce(0) { $0 + $1.rule.amount(income: income) } }

    func saveIncome(_ draft: PlannedIncomeDraft, id: UUID?) -> String? {
        guard draft.isValid, let amount = draft.amount else {
            return "Enter a source name up to 60 characters and a positive amount."
        }
        let duplicate = incomeSources.contains {
            $0.id != id && $0.name.compare(draft.trimmedName,
                options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        guard !duplicate else { return "An expected income source with this name already exists." }
        let source = PlannedIncomeSource(id: id ?? UUID(), name: draft.trimmedName, amount: amount)
        if let index = incomeSources.firstIndex(where: { $0.id == source.id }) {
            incomeSources[index] = source
        } else {
            incomeSources.append(source)
        }
        return nil
    }

    func deleteIncome(id: UUID) {
        incomeSources.removeAll { $0.id == id }
    }

    func updateAllocation(id: UUID, rule: PlanAllocationRule, groupID: UUID) {
        guard groups.contains(where: { $0.id == groupID }),
              let index = allocations.firstIndex(where: { $0.id == id }) else { return }
        allocations[index].rule = rule
        allocations[index].groupID = groupID
    }

    func saveGroup(_ draft: PlanGroupDraft, id: UUID?) -> String? {
        guard draft.isValid else {
            return "Enter a section name up to 40 characters and a description up to 100 characters."
        }
        let duplicate = groups.contains {
            $0.id != id && $0.name.compare(draft.trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        guard !duplicate else {
            return "A Plan section with this name already exists."
        }
        let group = PlanGroup(id: id ?? UUID(), name: draft.trimmedName,
                              subtitle: draft.trimmedSubtitle, symbol: draft.symbol, color: draft.color)
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
        } else {
            groups.append(group)
        }
        return nil
    }

    func moveGroups(from source: IndexSet, to destination: Int) {
        let moving = source.sorted().map { groups[$0] }
        let remaining = groups.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let adjustedDestination = destination - source.filter { $0 < destination }.count
        groups = remaining
        groups.insert(contentsOf: moving, at: min(max(adjustedDestination, 0), groups.count))
    }

    func deleteGroups(ids: Set<UUID>) {
        groups.removeAll { ids.contains($0.id) }
        // Removing an allocation releases its planned amount back to Unallocated.
        allocations.removeAll { ids.contains($0.groupID) }
    }

    func deleteAllocation(id: UUID) {
        allocations.removeAll { $0.id == id }
    }

    func allocatedAmount(inGroupIDs ids: Set<UUID>) -> Decimal {
        allocations.filter { ids.contains($0.groupID) }
            .reduce(0) { $0 + $1.rule.amount(income: income) }
    }
}
