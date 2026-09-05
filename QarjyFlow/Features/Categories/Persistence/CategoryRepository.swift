import Foundation
import SwiftData

/// Production instance is confined to LedgerDatabase; preview/test instances stay on their own executor.
/// Never share a repository across executors.

final class CategoryRepository {
    // Dedicated context: rollback cannot discard unrelated screen edits.
    private let container: ModelContainer
    private var context: ModelContext

    init(container: ModelContainer) {
        self.container = container
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func fetchAll() throws -> [CategoryItem] {
        resetContext()
        return try context.fetch(FetchDescriptor<CategoryRecord>()).map(\.item)
    }

    func save(_ draft: CategoryDraft, id: UUID?) throws -> CategoryItem {
        resetContext()
        try draft.validate()
        let records = try context.fetch(FetchDescriptor<CategoryRecord>())
        guard !records.contains(where: {
            $0.id != id && $0.kindRawValue == draft.kind.rawValue && $0.normalizedName == draft.normalizedName
        }) else { throw CategoryError.duplicateName }

        let record: CategoryRecord
        if let id {
            guard let existing = records.first(where: { $0.id == id }) else { throw CategoryError.notFound }
            if existing.kindRawValue != draft.kind.rawValue {
                guard try !isUsed(id) else { throw CategoryError.inUse }
            }
            record = existing
            record.name = draft.trimmedName
            record.normalizedName = draft.normalizedName
            record.kindRawValue = draft.kind.rawValue
            record.symbol = draft.symbol
            record.colorRawValue = draft.color.rawValue
        } else {
            record = CategoryRecord(draft: draft)
            context.insert(record)
        }
        try commit()
        return record.item
    }

    func setArchived(_ archived: Bool, id: UUID) throws -> CategoryItem {
        resetContext()
        let record = try find(id)
        record.isArchived = archived
        try commit()
        return record.item
    }

    func delete(id: UUID) throws {
        resetContext()
        guard try !isUsed(id) else { throw CategoryError.inUse }
        context.delete(try find(id))
        try commit()
    }

    private func resetContext() {
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    private func isUsed(_ id: UUID) throws -> Bool {
        let descriptor = FetchDescriptor<TransactionRecord>(predicate: #Predicate { $0.categoryID == id })
        if try context.fetchCount(descriptor) > 0 { return true }
        return try context.fetch(FetchDescriptor<PlanAllocationRecord>()).contains { $0.categoryID == id }
    }

    private func find(_ id: UUID) throws -> CategoryRecord {
        let descriptor = FetchDescriptor<CategoryRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try context.fetch(descriptor).first else { throw CategoryError.notFound }
        return record
    }

    private func commit() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            // A failed SwiftData save can leave registered objects reflecting edits
            // even after rollback. Never reuse that context for subsequent reads.
            context = ModelContext(container)
            context.autosaveEnabled = false
            throw error
        }
    }
}
