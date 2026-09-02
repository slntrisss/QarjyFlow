import Foundation
import SwiftData
import XCTest
@testable import CategoriesCore

@MainActor
final class CategoryStoreTests: XCTestCase {
    private func makeStore() throws -> CategoryRepository {
        CategoryRepository(container: try AppDatabase.makeContainer(inMemory: true))
    }

    private func draft(_ name: String, kind: CategoryKind = .expense) -> CategoryDraft {
        var draft = CategoryDraft()
        draft.name = name
        draft.kind = kind
        return draft
    }

    func testCreateEditArchiveRestoreAndDelete() throws {
        let store = try makeStore()
        let initial = try store.save(draft("  Groceries  "), id: nil)
        XCTAssertEqual(initial.name, "Groceries")
        let edited = try store.save(draft("Food"), id: initial.id)
        XCTAssertEqual(edited.id, initial.id)
        XCTAssertEqual(try store.fetchAll().count, 1)
        XCTAssertTrue(try store.setArchived(true, id: initial.id).isArchived)
        XCTAssertFalse(try store.setArchived(false, id: initial.id).isArchived)
        try store.delete(id: initial.id)
        XCTAssertTrue(try store.fetchAll().isEmpty)
    }

    func testDuplicateNamesIncludeArchivedAndAllowDifferentTypes() throws {
        let store = try makeStore()
        let item = try store.save(draft("Coffee Shops"), id: nil)
        _ = try store.setArchived(true, id: item.id)
        XCTAssertThrowsError(try store.save(draft("  COFFEE   SHOPS "), id: nil))
        _ = try store.save(draft("Coffee Shops", kind: .income), id: nil)
        XCTAssertEqual(try store.fetchAll().count, 2)
        // Renaming an item to its own normalized name is valid.
        _ = try store.save(draft("Coffee Shops"), id: item.id)
    }

    func testValidationAndConflictingRenameDoNotChangeSavedData() throws {
        let store = try makeStore()
        let food = try store.save(draft("Food"), id: nil)
        _ = try store.save(draft("Rent"), id: nil)
        for name in ["   ", String(repeating: "a", count: 61), "One\nTwo"] {
            XCTAssertThrowsError(try store.save(draft(name), id: food.id))
        }
        XCTAssertThrowsError(try store.save(draft("Rent"), id: food.id))
        var invalidIcon = draft("Valid")
        invalidIcon.symbol = "not-a-supported-symbol"
        XCTAssertThrowsError(try store.save(invalidIcon, id: nil))
        XCTAssertEqual(try store.fetchAll().first { $0.id == food.id }?.name, "Food")
        XCTAssertEqual(try store.fetchAll().count, 2)
    }

    func testMissingIDsCannotCreateOrDeleteOtherItems() throws {
        let store = try makeStore()
        XCTAssertThrowsError(try store.save(draft("Food"), id: UUID()))
        XCTAssertThrowsError(try store.delete(id: UUID()))
        XCTAssertThrowsError(try store.setArchived(true, id: UUID()))
        XCTAssertTrue(try store.fetchAll().isEmpty)
    }

    func testDataSurvivesOpeningANewDiskContainer() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("categories.store")
        let id = try autoreleasepool {
            let store = CategoryRepository(container: try AppDatabase.makeContainer(url: url))
            let item = try store.save(draft("Travel"), id: nil)
            _ = try store.setArchived(true, id: item.id)
            return item.id
        }
        try autoreleasepool {
            let reopened = CategoryRepository(container: try AppDatabase.makeContainer(url: url))
            let items = try reopened.fetchAll()
            XCTAssertEqual(items.count, 1)
            XCTAssertEqual(items.first?.id, id)
            XCTAssertEqual(items.first?.name, "Travel")
            XCTAssertEqual(items.first?.isArchived, true)
        }
    }

    func testInMemoryContainersAreIsolated() throws {
        let first = try makeStore()
        _ = try first.save(draft("Food"), id: nil)
        XCTAssertTrue(try makeStore().fetchAll().isEmpty)
    }

    func testFailedSaveRollsBackChanges() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly.store")
        let id = try autoreleasepool {
            let store = CategoryRepository(container: try AppDatabase.makeContainer(url: url))
            return try store.save(draft("Food"), id: nil).id
        }
        let schema = Schema([CategoryRecord.self, TransactionRecord.self])
        let configuration = ModelConfiguration(
            schema: schema, url: url, allowsSave: false, cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let store = CategoryRepository(container: container)
        XCTAssertThrowsError(try store.save(draft("Changed"), id: id))
        XCTAssertEqual(try store.fetchAll().first?.name, "Food")
        XCTAssertThrowsError(try store.save(draft("New"), id: nil))
        XCTAssertEqual(try store.fetchAll().count, 1)
    }
}
