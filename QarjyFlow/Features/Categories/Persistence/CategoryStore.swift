import Foundation

/// A feature-specific persistence boundary, also used by preview/test doubles.
@MainActor
protocol CategoryStore {
    func fetchAll() throws -> [CategoryItem]
    func save(_ draft: CategoryDraft, id: UUID?) throws -> CategoryItem
    func setArchived(_ archived: Bool, id: UUID) throws -> CategoryItem
    func delete(id: UUID) throws
}
