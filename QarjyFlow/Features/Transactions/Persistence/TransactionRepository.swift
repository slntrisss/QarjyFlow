import Foundation
import SwiftData
import os

/// Production instance is confined to LedgerDatabase; preview/test instances stay on their own executor.
/// Never share a repository across executors.

final class TransactionRepository {
    private let container: ModelContainer

    init(container: ModelContainer) { self.container = container }

    func fetchAll() throws -> [TransactionItem] {
        let context = makeContext()
        return try context.fetch(FetchDescriptor<TransactionRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
            .map(\.item)
    }

    func save(_ draft: TransactionDraft, id: UUID?) throws -> TransactionItem {
        try draft.validate()
        let context = makeContext()
        let previous: TransactionRecord?
        if let id {
            previous = try find(id, in: context)
        } else {
            previous = nil
        }
        guard let categoryID = draft.categoryID,
              let category = try context.fetch(FetchDescriptor<CategoryRecord>())
                .first(where: { $0.id == categoryID }) else { throw TransactionError.invalidCategory }
        guard category.kindRawValue == draft.kind.rawValue else { throw TransactionError.kindMismatch }
        // Existing history can retain its archived category when edited.
        guard !category.isArchived || previous?.categoryID == categoryID else {
            throw TransactionError.archivedCategory
        }
        let amount = try draft.amountMinor()
        let record: TransactionRecord
        if let previous {
            record = previous
            record.amountMinor = amount
            record.kindRawValue = draft.kind.rawValue
            record.categoryID = categoryID
            record.date = draft.date
            record.merchant = draft.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
            record.note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            record = TransactionRecord(amountMinor: amount, categoryID: categoryID, draft: draft)
            context.insert(record)
        }
        try commit(context)
        return record.item
    }

    func delete(id: UUID) throws {
        let context = makeContext()
        context.delete(try find(id, in: context))
        try commit(context)
    }

    private func makeContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func find(_ id: UUID, in context: ModelContext) throws -> TransactionRecord {
        let descriptor = FetchDescriptor<TransactionRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try context.fetch(descriptor).first else { throw TransactionError.notFound }
        return record
    }

    private func commit(_ context: ModelContext) throws {
        do { try context.save() }
        catch {
            AppLog.persistence.error("Transaction save failed: \(String(describing: error), privacy: .private(mask: .hash))")
            context.rollback()
            // The failed context is discarded when this operation exits.
            throw error
        }
    }
}
