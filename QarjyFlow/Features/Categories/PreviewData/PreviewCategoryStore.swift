import Foundation

@MainActor
final class PreviewCategoryStore: CategoryStore {
    private let repository: CategoryRepository
    init(repository: CategoryRepository) { self.repository = repository }

    func fetchAll() throws -> [CategoryItem] { try repository.fetchAll() }
    func save(_ draft: CategoryDraft, id: UUID?) throws -> CategoryItem { try repository.save(draft, id: id) }
    func delete(id: UUID) throws { try repository.delete(id: id) }
    func setArchived(_ archived: Bool, id: UUID) throws -> CategoryItem { try repository.setArchived(archived, id: id) }
}
