import Foundation
import SwiftData

@MainActor
final class SwiftDataCategoryStore: CategoryStore {
    // Dedicated context: rollback cannot discard unrelated screen edits.
    private let container: ModelContainer
    private var context: ModelContext

    init(container: ModelContainer) {
        self.container = container
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func fetchAll() throws -> [CategoryItem] {
        try context.fetch(FetchDescriptor<CategoryRecord>()).map(\.item)
    }

    func save(_ draft: CategoryDraft, id: UUID?) throws -> CategoryItem {
        try draft.validate()
        let records = try context.fetch(FetchDescriptor<CategoryRecord>())
        guard !records.contains(where: {
            $0.id != id && $0.kindRawValue == draft.kind.rawValue && $0.normalizedName == draft.normalizedName
        }) else { throw CategoryError.duplicateName }

        let record: CategoryRecord
        if let id {
            guard let existing = records.first(where: { $0.id == id }) else { throw CategoryError.notFound }
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
        let record = try find(id)
        record.isArchived = archived
        try commit()
        return record.item
    }

    func delete(id: UUID) throws {
        // This milestone has no transactions or budgets, so every category is unused.
        // Add a reference check/delete rule before introducing those relationships.
        context.delete(try find(id))
        try commit()
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
