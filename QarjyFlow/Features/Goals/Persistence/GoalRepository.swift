import Foundation
import SwiftData

final class GoalRepository {
    private let container: ModelContainer
    init(container: ModelContainer) { self.container = container }

    func fetchSnapshot() throws -> GoalSnapshot {
        let context = ModelContext(container)
        let goals = try context.fetch(FetchDescriptor<FinancialGoalRecord>()).map(materialize)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let contributions = try context.fetch(
            FetchDescriptor<GoalContributionRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        ).map { GoalContribution(id: $0.id, goalID: $0.goalID, amountMinor: $0.amountMinor,
                                 date: $0.date, note: $0.note) }
        return GoalSnapshot(goals: goals, contributions: contributions)
    }

    func save(_ draft: GoalDraft, id: UUID?) throws -> FinancialGoal {
        let name = draft.trimmedName
        guard !name.isEmpty, name.count <= 60,
              draft.kind == .ongoing || draft.targetAmount != nil else { throw GoalError.invalidGoal }
        let normalized = normalize(name)
        let context = ModelContext(container); context.autosaveEnabled = false
        let records = try context.fetch(FetchDescriptor<FinancialGoalRecord>())
        guard !records.contains(where: { $0.id != id && $0.normalizedName == normalized })
        else { throw GoalError.duplicateName }
        let goal = FinancialGoal(id: id ?? UUID(), name: name, kind: draft.kind,
                                 targetAmount: draft.kind == .target ? draft.targetAmount : nil,
                                 symbol: draft.symbol, color: draft.color)
        if let id {
            guard let record = records.first(where: { $0.id == id }) else { throw GoalError.notFound }
            record.name = goal.name; record.normalizedName = normalized
            record.kindRawValue = goal.kind.rawValue; record.targetMinor = goal.targetAmount?.minorUnits
            record.symbol = goal.symbol; record.colorRawValue = goal.color.rawValue
        } else { context.insert(FinancialGoalRecord(goal: goal)) }
        try context.save()
        return goal
    }

    func addContribution(goalID: UUID, amountText: String, date: Date, note: String) throws -> GoalContribution {
        guard let minor = AmountInputParsing.positiveMinorUnits(amountText) else {
            throw GoalError.invalidContribution
        }
        let context = ModelContext(container); context.autosaveEnabled = false
        guard try context.fetch(FetchDescriptor<FinancialGoalRecord>()).contains(where: { $0.id == goalID })
        else { throw GoalError.notFound }
        let value = GoalContribution(id: UUID(), goalID: goalID, amountMinor: minor,
                                     date: date, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(GoalContributionRecord(value)); try context.save(); return value
    }

    func deleteContribution(id: UUID) throws {
        let context = ModelContext(container); context.autosaveEnabled = false
        guard let record = try context.fetch(FetchDescriptor<GoalContributionRecord>()).first(where: { $0.id == id })
        else { throw GoalError.notFound }
        context.delete(record); try context.save()
    }

    func deleteGoal(id: UUID) throws {
        let context = ModelContext(container); context.autosaveEnabled = false
        guard let goal = try context.fetch(FetchDescriptor<FinancialGoalRecord>())
            .first(where: { $0.id == id }) else { throw GoalError.notFound }
        let isLinked = try context.fetch(FetchDescriptor<PlanGoalLinkRecord>())
            .contains(where: { $0.goalID == id })
        guard !isLinked else { throw GoalError.inUse }
        try context.fetch(FetchDescriptor<GoalContributionRecord>())
            .filter { $0.goalID == id }.forEach(context.delete)
        context.delete(goal)
        try context.save()
    }

    private func materialize(_ record: FinancialGoalRecord) -> FinancialGoal {
        FinancialGoal(id: record.id, name: record.name,
                      kind: GoalKind(rawValue: record.kindRawValue) ?? .ongoing,
                      targetAmount: record.targetMinor.map { Decimal.fromMinorUnits($0) },
                      symbol: record.symbol, color: ThemeColor(rawValue: record.colorRawValue) ?? .blue)
    }
    private func normalize(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
