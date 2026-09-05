import Foundation
import SwiftData

/// Production instance is confined to LedgerDatabase. It never escapes SwiftData records.
final class PlanRepository {
    private let container: ModelContainer
    init(container: ModelContainer) { self.container = container }

    func fetch(month: PlanMonth) throws -> MonthlyPlan? {
        let context = makeContext()
        let records = try context.fetch(FetchDescriptor<MonthlyPlanRecord>())
        guard let plan = records.first(where: { $0.monthKey == month.key }) else { return nil }
        return try materialize(plan, in: context)
    }

    func save(_ value: MonthlyPlan) throws -> MonthlyPlan {
        try validate(value)
        let context = makeContext()
        let plans = try context.fetch(FetchDescriptor<MonthlyPlanRecord>())
        let record: MonthlyPlanRecord
        if let existing = plans.first(where: { $0.id == value.id }) {
            guard existing.monthKey == value.month.key else { throw PlanError.invalidPlan }
            record = existing
        } else {
            guard !plans.contains(where: { $0.monthKey == value.month.key }) else { throw PlanError.duplicateMonth }
            record = MonthlyPlanRecord(id: value.id, month: value.month)
            context.insert(record)
        }

        try synchronizeIncome(value, in: context)
        try synchronizeGroups(value, in: context)
        try synchronizeAllocations(value, in: context)
        do { try context.save() }
        catch { context.rollback(); throw error }
        return try materialize(record, in: context)
    }

    private func validate(_ plan: MonthlyPlan) throws {
        let groupIDs = Set(plan.groups.map(\.id))
        let incomeNames = plan.incomeSources.map { normalized($0.name) }
        let groupNames = plan.groups.map { normalized($0.name) }
        let categoryIDs = plan.allocations.compactMap(\.categoryID)
        guard groupIDs.count == plan.groups.count,
              Set(plan.incomeSources.map(\.id)).count == plan.incomeSources.count,
              Set(plan.allocations.map(\.id)).count == plan.allocations.count,
              Set(incomeNames).count == incomeNames.count,
              Set(groupNames).count == groupNames.count,
              Set(categoryIDs).count == categoryIDs.count,
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

    private func isExactPositiveMoney(_ value: Decimal) -> Bool {
        value > 0 && value.minorUnits > 0 && Decimal.fromMinorUnits(value.minorUnits) == value
    }

    private func synchronizeIncome(_ plan: MonthlyPlan, in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<PlannedIncomeRecord>()).filter { $0.planID == plan.id }
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
        let existing = try context.fetch(FetchDescriptor<PlanGroupRecord>()).filter { $0.planID == plan.id }
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
        let existing = try context.fetch(FetchDescriptor<PlanAllocationRecord>()).filter { $0.planID == plan.id }
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
            } else { context.insert(PlanAllocationRecord(allocation: allocation, planID: plan.id)) }
        }
    }

    private func materialize(_ plan: MonthlyPlanRecord, in context: ModelContext) throws -> MonthlyPlan {
        let income = try context.fetch(FetchDescriptor<PlannedIncomeRecord>()).filter { $0.planID == plan.id }
            .map { PlannedIncomeSource(id: $0.id, name: $0.name, amount: .fromMinorUnits($0.amountMinor)) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let groups = try context.fetch(FetchDescriptor<PlanGroupRecord>()).filter { $0.planID == plan.id }
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { PlanGroup(id: $0.id, name: $0.name, subtitle: $0.subtitle, symbol: $0.symbol,
                             color: ThemeColor(rawValue: $0.colorRawValue) ?? .green) }
        let allocations = try context.fetch(FetchDescriptor<PlanAllocationRecord>()).filter { $0.planID == plan.id }
            .map { record in
                let value = Decimal.fromMinorUnits(record.valueMinor)
                return PlanAllocation(id: record.id, name: record.name, symbol: record.symbol,
                                      groupID: record.groupID, categoryID: record.categoryID,
                                      tracksContribution: record.tracksContribution,
                                      rule: record.modeRawValue == "percentage" ? .percentage(value) : .fixed(value))
            }
        return MonthlyPlan(id: plan.id, month: PlanMonth(year: plan.year, month: plan.month),
                           incomeSources: income, groups: groups, allocations: allocations)
    }

    private func makeContext() -> ModelContext {
        let context = ModelContext(container); context.autosaveEnabled = false; return context
    }
    private func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
