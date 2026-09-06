import XCTest
@testable import CategoriesCore

@MainActor
final class CategoriesViewModelTests: XCTestCase {
    func testFilteringAndMutationRefreshTheVisibleList() async throws {
        let database = try await LedgerDatabase.open(inMemory: true)
        let model = CategoriesViewModel(store: SwiftDataCategoryStore(database: database))
        await model.load()
        XCTAssertTrue(model.hasLoaded)
        var draft = CategoryDraft()
        draft.name = "Groceries"
        try await model.save(draft, id: nil)
        let item = try XCTUnwrap(model.visibleCategories.first)
        model.searchText = "groC"
        XCTAssertEqual(model.visibleCategories.count, 1)
        model.searchText = "missing"
        XCTAssertTrue(model.visibleCategories.isEmpty)
        model.searchText = ""
        _ = try await database.setArchived(true, id: item.id)
        await model.load()
        XCTAssertTrue(model.visibleCategories.isEmpty)
        await model.delete(item)
        XCTAssertTrue(model.categories.isEmpty)
    }
}

extension CategoriesViewModelTests {
    func testLateRefreshCannotOverwriteCompletedSave() async throws {
        let store = DelayedCategoryStore()
        let model = CategoriesViewModel(store: store)
        let loading = Task { await model.load() }
        await fulfillment(of: [store.fetchStarted], timeout: 2)
        var draft = CategoryDraft()
        draft.name = "New category"
        try await model.save(draft, id: nil)
        store.completeFetch()
        await loading.value
        XCTAssertEqual(model.categories.map(\.name), ["New category"])
    }
}

@MainActor
private final class DelayedCategoryStore: CategoryStore {
    let fetchStarted = XCTestExpectation(description: "Fetch suspended")
    private var continuation: CheckedContinuation<[CategoryItem], Never>?
    func fetchAll() async throws -> [CategoryItem] {
        await withCheckedContinuation {
            continuation = $0
            fetchStarted.fulfill()
        }
    }
    func completeFetch() { continuation?.resume(returning: []); continuation = nil }
    func save(_ draft: CategoryDraft, id: UUID?) throws -> CategoryItem {
        CategoryItem(id: id ?? UUID(), name: draft.name, kind: draft.kind,
                     symbol: draft.symbol, color: draft.color, isArchived: false)
    }
    func setArchived(_ archived: Bool, id: UUID) throws -> CategoryItem { throw CategoryError.notFound }
    func delete(id: UUID) throws { throw CategoryError.notFound }
}
