import Foundation

// TODO(ID-4): move preview/test fixtures into a DEBUG-only preview-support module or
// wrap this file plus every referencing #Preview in `#if DEBUG`. Do it in Xcode where
// the app target compiles. Production no longer depends on these types.
@MainActor
enum CategoryPreviewData {
    static let food = CategoryItem(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        name: "Groceries", kind: .expense, symbol: "fork.knife", color: .orange, isArchived: false
    )

    /// Only previews call this factory. It never opens the user's on-disk store.
    static func makeStore(seed: Bool = true) -> PreviewCategoryStore {
        do {
            let store = PreviewCategoryStore(repository: CategoryRepository(container: try AppDatabase.makeContainer(inMemory: true)))
            if seed {
                _ = try store.save(CategoryDraft(category: food), id: nil)
                var salary = CategoryDraft()
                salary.name = "Salary"
                salary.kind = .income
                salary.symbol = "briefcase.fill"
                _ = try store.save(salary, id: nil)
            }
            return store
        } catch {
            // Fail loudly in Canvas rather than pretending a broken preview loaded.
            fatalError("Could not build preview store: \(error)")
        }
    }
}
