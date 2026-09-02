import Foundation

/// A feature-specific persistence boundary, also used by preview/test doubles.
protocol CategoryStore: Sendable {
    func fetchAll() async throws -> [CategoryItem]
    func save(_ draft: CategoryDraft, id: UUID?) async throws -> CategoryItem
    func setArchived(_ archived: Bool, id: UUID) async throws -> CategoryItem
    func delete(id: UUID) async throws
}
