import Foundation

struct SwiftDataCategoryStore: CategoryStore {
    let database: LedgerDatabase

    func fetchAll() async throws -> [CategoryItem] { try await database.fetchCategories() }
    func save(_ draft: CategoryDraft, id: UUID?) async throws -> CategoryItem { try await database.saveCategory(draft, id: id) }
    func delete(id: UUID) async throws { try await database.deleteCategory(id: id) }
    func setArchived(_ archived: Bool, id: UUID) async throws -> CategoryItem { try await database.setArchived(archived, id: id) }
}
