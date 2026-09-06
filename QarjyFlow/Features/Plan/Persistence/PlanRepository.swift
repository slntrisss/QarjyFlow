import Foundation
import SwiftData
import os

/// Production instance is confined to LedgerDatabase. It never escapes SwiftData records.
final class PlanRepository {
    private let container: ModelContainer
    init(container: ModelContainer) { self.container = container }

    func fetch(month: PlanMonth) throws -> MonthlyPlan? {
        let context = makeContext()
        let key = month.key
        var descriptor = FetchDescriptor<MonthlyPlanRecord>(predicate: #Predicate { $0.monthKey == key })
        descriptor.fetchLimit = 1
        guard let plan = try context.fetch(descriptor).first else { return nil }
        return try materialize(plan, in: context)
    }

    func save(_ value: MonthlyPlan) throws -> MonthlyPlan {
        try validate(value)
        let context = makeContext()
        let planID = value.id
        let record: MonthlyPlanRecord
        if let existing = try context.fetch(
            FetchDescriptor<MonthlyPlanRecord>(predicate: #Predicate { $0.id == planID })
        ).first {
            guard existing.monthKey == value.month.key else { throw PlanError.invalidPlan }
            record = existing
        } else {
            let key = value.month.key
            let duplicates = try context.fetchCount(
                FetchDescriptor<MonthlyPlanRecord>(predicate: #Predicate { $0.monthKey == key })
            )
            guard duplicates == 0 else { throw PlanError.duplicateMonth }
            record = MonthlyPlanRecord(id: value.id, month: value.month)
            context.insert(record)
        }

        try synchronizeIncome(value, in: context)
        try synchronizeGroups(value, in: context)
        try synchronizeGoalLinks(value, in: context)
        try synchronizeAllocations(value, in: context)
        do { try context.save() }
        catch {
            AppLog.persistence.error("Plan save failed: \(String(describing: error), privacy: .private(mask: .hash))")
            context.rollback()
            throw error
        }
        return try materialize(record, in: context)
    }

    private func validate(_ plan: MonthlyPlan) throws {
        let groupIDs = Set(plan.groups.map(\.id))
        let incomeNames = plan.incomeSources.map { normalized($0.name) }
        let groupNames = plan.groups.map { normalized($0.name) }
        let categoryIDs = plan.allocations.compactMap(\.categoryID)
        let goalIDs = plan.allocations.compactMap(\.goalID)
        guard groupIDs.count == plan.groups.count,
              Set(plan.incomeSources.map(\.id)).count == plan.incomeSources.count,
              Set(plan.allocations.map(\.id)).count == plan.allocations.count,
              Set(incomeNames).count == incomeNames.count,
              Set(groupNames).count == groupNames.count,
              Set(categoryIDs).count == categoryIDs.count,
              Set(goalIDs).count == goalIDs.count,
              plan.allocations.allSatisfy({ !($0.categoryID != nil && $0.goalID != nil) }),
              plan.incomeSources.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              plan.groups.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              plan.allocations.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              plan.allocations.allSatisfy({ groupIDs.contains($0.groupID) }),
              plan.incomeSources.allSatisfy({ isExactPositiveMoney($0.amount) }),
              plan.allocations.allSatisfy({ allocation in
                  switch allocation.rule {
                  case .fixed(let amount): return isExactPositiveMoney(amount)
                  case .percentage(let percent):
                      return percent > 0 && percent <= 100 && Decimal.fromMinorUnits(percent.minorUnits) == percent
                  }
              })
        else { throw PlanError.invalidPlan }
    }

    private func synchronizeGoalLinks(_ plan: MonthlyPlan, in context: ModelContext) throws {
        let allocationIDs = Set(plan.allocations.map(\.id))
        let pid = plan.id
        let previousAllocationIDs = Set(try context.fetch(
            FetchDescriptor<PlanAllocationRecord>(predicate: #Predicate { $0.planID == pid })
        ).map(\.id))
        let existing = try context.fetch(FetchDescriptor<PlanGoalLinkRecord>())
            .filter { allocationIDs.contains($0.allocationID) || previousAllocationIDs.contains($0.allocationID) }
        let linked = plan.allocations.compactMap { allocation -> (UUID, UUID)? in
            allocation.goalID.map { (allocation.id, $0) }
        }
        let goalIDs = Set(linked.map(\.1))
        let storedGoalIDs = Set(try context.fetch(FetchDescriptor<FinancialGoalRecord>()).map(\.id))
        guard goalIDs.isSubset(of: storedGoalIDs) else { throw PlanError.invalidPlan }
        let linkedAllocationIDs = Set(linked.map(\.0))
        existing.filter { !linkedAllocationIDs.contains($0.allocationID) }.forEach(context.delete)
        for (allocationID, goalID) in linked {
            if let record = existing.first(where: { $0.allocationID == allocationID }) { record.goalID = goalID }
            else { context.insert(PlanGoalLinkRecord(allocationID: allocationID, goalID: goalID)) }
        }
    }

    private func isExactPositiveMoney(_ value: Decimal) -> Bool {
        value > 0 && value.minorUnits > 0 && Decimal.fromMinorUnits(value.minorUnits) == value
    }

    private func synchronizeIncome(_ plan: MonthlyPlan, in context: ModelContext) throws {
        let pid = plan.id
        let existing = try context.fetch(
            FetchDescriptor<PlannedIncomeRecord>(predicate: #Predicate { $0.planID == pid })
        )
        let ids = Set(plan.incomeSources.map(\.id))
        existing.filter { !ids.contains($0.id) }.forEach(context.delete)
        for source in plan.incomeSources {
            if let record = existing.first(where: { $0.id == source.id }) {
                record.name = source.name; record.normalizedName = normalized(source.name)
                record.amountMinor = source.amount.minorUnits
            } else {
                context.insert(PlannedIncomeRecord(id: source.id, planID: plan.id,
                                                   name: source.name, amountMinor: source.amount.minorUnits))
            }
        }
    }

    private func synchronizeGroups(_ plan: MonthlyPlan, in context: ModelContext) throws {
        let pid = plan.id
        let existing = try context.fetch(
            FetchDescriptor<PlanGroupRecord>(predicate: #Predicate { $0.planID == pid })
        )
        let ids = Set(plan.groups.map(\.id))
        existing.filter { !ids.contains($0.id) }.forEach(context.delete)
        for (order, group) in plan.groups.enumerated() {
            if let record = existing.first(where: { $0.id == group.id }) {
                record.name = group.name; record.normalizedName = normalized(group.name)
                record.subtitle = group.subtitle; record.symbol = group.symbol
                record.colorRawValue = group.color.rawValue; record.sortOrder = order
            } else { context.insert(PlanGroupRecord(group: group, planID: plan.id, sortOrder: order)) }
        }
    }

    private func synchronizeAllocations(_ plan: MonthlyPlan, in context: ModelContext) throws {
        let categories = try context.fetch(FetchDescriptor<CategoryRecord>())
        for allocation in plan.allocations {
            if let categoryID = allocation.categoryID {
                guard let category = categories.first(where: { $0.id == categoryID }),
                      category.kindRawValue == CategoryKind.expense.rawValue else { throw PlanError.categoryUnavailable }
            }
        }
        let pid = plan.id
        let existing = try context.fetch(
            FetchDescriptor<PlanAllocationRecord>(predicate: #Predicate { $0.planID == pid })
        )
        let ids = Set(plan.allocations.map(\.id))
        existing.filter { !ids.contains($0.id) }.forEach(context.delete)
        for allocation in plan.allocations {
            if let record = existing.first(where: { $0.id == allocation.id }) {
                record.groupID = allocation.groupID; record.categoryID = allocation.categoryID
                record.name = allocation.name; record.symbol = allocation.symbol
                record.tracksContribution = allocation.tracksContribution
                switch allocation.rule {
                case .fixed(let amount): record.modeRawValue = "fixed"; record.valueMinor = amount.minorUnits
                case .percentage(let value): record.modeRawValue = "percentage"; record.valueMinor = value.minorUnits
                }
            } else {
                context.insert(PlanAllocationRecord(allocation: allocation, planID: plan.id))
            }
        }
    }

    private func materialize(_ plan: MonthlyPlanRecord, in context: ModelContext) throws -> MonthlyPlan {
        let pid = plan.id
        let income = try context.fetch(
            FetchDescriptor<PlannedIncomeRecord>(predicate: #Predicate { $0.planID == pid })
        )
            .map { PlannedIncomeSource(id: $0.id, name: $0.name, amount: .fromMinorUnits($0.amountMinor)) }
            .sorted { (left: PlannedIncomeSource, right: PlannedIncomeSource) in
                left.name.localizedStandardCompare(right.name) == .orderedAscending
            }
        let groups = try context.fetch(
            FetchDescriptor<PlanGroupRecord>(predicate: #Predicate { $0.planID == pid })
        )
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { PlanGroup(id: $0.id, name: $0.name, subtitle: $0.subtitle, symbol: $0.symbol,
                             color: ThemeColor(rawValue: $0.colorRawValue) ?? .green) }
        let allocations = try context.fetch(
            FetchDescriptor<PlanAllocationRecord>(predicate: #Predicate { $0.planID == pid })
        )
        let links = try context.fetch(FetchDescriptor<PlanGoalLinkRecord>())
        let goalByAllocation = Dictionary(uniqueKeysWithValues: links.map { ($0.allocationID, $0.goalID) })
        let materializedAllocations = allocations.map { record in
                let value = Decimal.fromMinorUnits(record.valueMinor)
                return PlanAllocation(id: record.id, name: record.name, symbol: record.symbol,
                                      groupID: record.groupID, categoryID: record.categoryID,
                                      goalID: goalByAllocation[record.id],
                                      tracksContribution: record.tracksContribution,
                                      rule: record.modeRawValue == "percentage" ? .percentage(value) : .fixed(value))
            }
            .sorted { (left: PlanAllocation, right: PlanAllocation) in
                left.name.localizedStandardCompare(right.name) == .orderedAscending
            }
        return MonthlyPlan(id: plan.id, month: PlanMonth(year: plan.year, month: plan.month),
                           incomeSources: income, groups: groups, allocations: materializedAllocations)
    }

    private func makeContext() -> ModelContext {
        let context = ModelContext(container); context.autosaveEnabled = false; return context
    }
    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
