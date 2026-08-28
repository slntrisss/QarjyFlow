import XCTest
@testable import CategoriesCore

@MainActor
final class CategoriesViewModelTests: XCTestCase {
    func testFilteringAndMutationRefreshTheVisibleList() throws {
        let model = CategoriesViewModel(store: SwiftDataCategoryStore(
            container: try AppDatabase.makeContainer(inMemory: true)
        ))
        model.load()
        XCTAssertTrue(model.hasLoaded)
        var draft = CategoryDraft()
        draft.name = "Groceries"
        try model.save(draft, id: nil)
        let item = try XCTUnwrap(model.visibleCategories.first)
        model.searchText = "groC"
        XCTAssertEqual(model.visibleCategories.count, 1)
        model.searchText = "missing"
        XCTAssertTrue(model.visibleCategories.isEmpty)
        model.searchText = ""
        model.setArchived(true, category: item)
        XCTAssertTrue(model.visibleCategories.isEmpty)
        model.showArchived = true
        XCTAssertEqual(model.visibleCategories.first?.id, item.id)
        model.delete(item)
        XCTAssertTrue(model.categories.isEmpty)
    }
}
