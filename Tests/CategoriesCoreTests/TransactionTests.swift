import Foundation
import SwiftData
import XCTest
@testable import CategoriesCore

@MainActor
final class TransactionTests: XCTestCase {
    private func fixture() throws -> (ModelContainer, SwiftDataCategoryStore, SwiftDataTransactionStore, CategoryItem) {
        let container = try AppDatabase.makeContainer(inMemory: true)
        let categories = SwiftDataCategoryStore(container: container)
        let transactions = SwiftDataTransactionStore(container: container)
        var category = CategoryDraft()
        category.name = "Food"
        return (container, categories, transactions, try categories.save(category, id: nil))
    }

    private func draft(_ category: CategoryItem, amount: String = "12.56") -> TransactionDraft {
        var draft = TransactionDraft()
        draft.categoryID = category.id
        draft.amountText = amount
        draft.kind = category.kind
        draft.date = Date(timeIntervalSince1970: 1_700_000_000)
        return draft
    }

    func testMoneyParsingIsExactAndRejectsAmbiguousInput() throws {
        var draft = TransactionDraft()
        for (text, expected) in [("12.56", Int64(1256)), ("12,5", 1250), ("0.01", 1), (" 100 ", 10000), ("999999999999.99", 99999999999999)] {
            draft.amountText = text
            XCTAssertEqual(try draft.amountMinor(), expected, text)
        }
        for text in ["", "0", "-1", "1e3", "1.234", "1,000", "1,234.56", "NaN", "1.", ".5", "1 000", "1000000000000"] {
            draft.amountText = text
            XCTAssertThrowsError(try draft.amountMinor(), text)
        }
    }

    func testAmountMaskGroupsTypingWithoutChangingTheSavedAmount() throws {
        var display = ""
        var raw = ""
        for digit in "1234567.50" {
            let edit = try XCTUnwrap(AmountInputFormatting.edit(
                display: display, range: NSRange(location: display.utf16.count, length: 0),
                replacement: String(digit)
            ))
            display = edit.displayText
            raw = edit.rawText
            XCTAssertEqual(edit.caretOffset, display.utf16.count)
        }
        XCTAssertEqual(display, "1 234 567.50")
        XCTAssertEqual(raw, "1234567.50")
        var draft = TransactionDraft()
        draft.amountText = raw
        XCTAssertEqual(try draft.amountMinor(), 123456750)
    }

    func testAmountMaskPreservesCaretForMiddleEditsAndBackspacing() throws {
        let middle = try XCTUnwrap(AmountInputFormatting.edit(
            display: "12 345", range: NSRange(location: 1, length: 0), replacement: "9"
        ))
        XCTAssertEqual(middle.displayText, "192 345")
        XCTAssertEqual(middle.caretOffset, 2)
        let lastDigit = try XCTUnwrap(AmountInputFormatting.edit(
            display: "1 000", range: NSRange(location: 4, length: 1), replacement: ""
        ))
        XCTAssertEqual(lastDigit.displayText, "100")
        XCTAssertEqual(lastDigit.caretOffset, 3)
        let space = try XCTUnwrap(AmountInputFormatting.edit(
            display: "1 000", range: NSRange(location: 1, length: 1), replacement: ""
        ))
        XCTAssertEqual(space.rawText, "000")
        XCTAssertEqual(space.caretOffset, 0)
        let cleared = try XCTUnwrap(AmountInputFormatting.edit(
            display: "1 000", range: NSRange(location: 0, length: 5), replacement: ""
        ))
        XCTAssertEqual(cleared.displayText, "")
    }

    func testAmountMaskHandlesPasteAndPartialDecimalsWithoutRounding() throws {
        let pasted = try XCTUnwrap(AmountInputFormatting.edit(
            display: "", range: NSRange(location: 0, length: 0), replacement: "1\u{202F}234,50"
        ))
        XCTAssertEqual(pasted.rawText, "1234,50")
        XCTAssertEqual(pasted.displayText, "1 234,50")
        XCTAssertEqual(AmountInputFormatting.rawText(from: "."), "0.")
        XCTAssertEqual(AmountInputFormatting.display("1000."), "1 000.")
        for input in ["-100", "1e3", "12.345", "1,234.50", "1000000000000", "₸100"] {
            XCTAssertNil(AmountInputFormatting.rawText(from: input), input)
        }
        XCTAssertNil(AmountInputFormatting.edit(
            display: "12", range: NSRange(location: 10, length: 1), replacement: "3"
        ))
    }

    func testCRUDAndCategoryProtections() throws {
        let (_, categories, store, food) = try fixture()
        var edit = draft(food)
        let item = try store.save(edit, id: nil)
        XCTAssertEqual(item.amountMinor, 1256)
        XCTAssertThrowsError(try categories.delete(id: food.id))
        var categoryEdit = CategoryDraft(category: food)
        categoryEdit.kind = .income
        XCTAssertThrowsError(try categories.save(categoryEdit, id: food.id))
        categoryEdit.kind = .expense
        categoryEdit.name = "Groceries"
        _ = try categories.save(categoryEdit, id: food.id)
        XCTAssertEqual(try store.fetchAll().first?.categoryID, food.id)
        _ = try categories.setArchived(true, id: food.id)
        XCTAssertThrowsError(try store.save(draft(food), id: nil))
        edit.amountText = "99.01"
        let updated = try store.save(edit, id: item.id)
        XCTAssertEqual(updated.id, item.id)
        XCTAssertEqual(updated.amountMinor, 9901)
        XCTAssertEqual(try store.fetchAll().count, 1)
        try store.delete(id: item.id)
        XCTAssertTrue(try store.fetchAll().isEmpty)
        try categories.delete(id: food.id)
        XCTAssertTrue(try categories.fetchAll().isEmpty)
    }

    func testValidationCannotCreateOrCorruptRecords() throws {
        let (_, _, store, food) = try fixture()
        let original = try store.save(draft(food), id: nil)
        var invalid = draft(food)
        invalid.kind = .income
        XCTAssertThrowsError(try store.save(invalid, id: original.id))
        invalid = draft(food)
        invalid.categoryID = UUID()
        XCTAssertThrowsError(try store.save(invalid, id: nil))
        invalid = draft(food)
        invalid.date = Date().addingTimeInterval(3 * 86400)
        XCTAssertThrowsError(try store.save(invalid, id: original.id))
        invalid = draft(food)
        invalid.note = String(repeating: "x", count: 501)
        XCTAssertThrowsError(try store.save(invalid, id: original.id))
        XCTAssertThrowsError(try store.save(draft(food), id: UUID()))
        XCTAssertThrowsError(try store.delete(id: UUID()))
        XCTAssertEqual(try store.fetchAll(), [original])
    }

    func testExistingCategoryOnlyDatabaseUpgradesAndTransactionsPersist() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("default.store")
        let categoryID = try autoreleasepool {
            let oldSchema = Schema([CategoryRecord.self])
            let config = ModelConfiguration(schema: oldSchema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: oldSchema, configurations: [config])
            let context = ModelContext(container)
            var draft = CategoryDraft()
            draft.name = "Existing category"
            let category = CategoryRecord(draft: draft)
            context.insert(category)
            try context.save()
            return category.id
        }
        let transactionID = try autoreleasepool {
            let container = try AppDatabase.makeContainer(url: url)
            let categories = SwiftDataCategoryStore(container: container)
            let category = try XCTUnwrap(categories.fetchAll().first)
            XCTAssertEqual(category.id, categoryID)
            XCTAssertEqual(category.name, "Existing category")
            return try SwiftDataTransactionStore(container: container).save(draft(category), id: nil).id
        }
        try autoreleasepool {
            let container = try AppDatabase.makeContainer(url: url)
            let item = try XCTUnwrap(SwiftDataTransactionStore(container: container).fetchAll().first)
            XCTAssertEqual(item.id, transactionID)
            XCTAssertEqual(item.categoryID, categoryID)
            XCTAssertEqual(item.amountMinor, 1256)
        }
    }

    func testMonthlySummaryUsesExactAmountsAndExclusiveEndBoundary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let formatter = ISO8601DateFormatter()
        func item(_ date: String, _ amount: Int64, _ kind: CategoryKind) -> TransactionItem {
            TransactionItem(id: UUID(), amountMinor: amount, kind: kind, categoryID: UUID(), date: formatter.date(from: date)!, merchant: "", note: "")
        }
        let items = [
            item("2026-08-01T00:00:00Z", 10000, .income),
            item("2026-08-31T23:59:59Z", 1256, .expense),
            item("2026-08-12T12:00:00Z", 1, .expense),
            item("2026-07-31T23:59:59Z", 10000, .expense),
            item("2026-09-01T00:00:00Z", 10000, .expense)
        ]
        let summary = TransactionSummary(transactions: items, month: formatter.date(from: "2026-08-15T00:00:00Z")!, calendar: calendar)
        XCTAssertEqual(summary.income, 100)
        XCTAssertEqual(summary.expense, Decimal(string: "12.57"))
        XCTAssertEqual(summary.net, Decimal(string: "87.43"))
        XCTAssertEqual(summary.count, 3)
    }

    func testViewModelUpdatesAfterSaveDeleteAndNewCategoryCreation() throws {
        let (_, categories, store, food) = try fixture()
        let model = TransactionsViewModel(store: store, categoryStore: categories)
        model.load()
        try model.save(draft(food), id: nil)
        var newCategory = CategoryDraft()
        newCategory.name = "Books"
        let books = try categories.save(newCategory, id: nil)
        model.load()
        XCTAssertEqual(model.categories.count, 2)
        try model.save(draft(books), id: nil)
        model.searchText = "Books"
        XCTAssertEqual(model.visibleTransactions.count, 1)
        model.filter = .income
        XCTAssertTrue(model.visibleTransactions.isEmpty)
        model.filter = nil
        let bookTransaction = try XCTUnwrap(model.visibleTransactions.first)
        model.delete(bookTransaction)
        XCTAssertEqual(model.transactions.count, 1)
        XCTAssertTrue(model.visibleTransactions.isEmpty)
    }

    func testFailedTransactionWritesLeaveTheLedgerUnchanged() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("readonly.store")
        let (category, original) = try autoreleasepool {
            let container = try AppDatabase.makeContainer(url: url)
            var categoryDraft = CategoryDraft()
            categoryDraft.name = "Food"
            let category = try SwiftDataCategoryStore(container: container).save(categoryDraft, id: nil)
            let original = try SwiftDataTransactionStore(container: container).save(draft(category), id: nil)
            return (category, original)
        }
        let schema = Schema([CategoryRecord.self, TransactionRecord.self])
        let config = ModelConfiguration(schema: schema, url: url, allowsSave: false, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let store = SwiftDataTransactionStore(container: container)
        XCTAssertThrowsError(try store.save(draft(category, amount: "900"), id: original.id))
        XCTAssertThrowsError(try store.save(draft(category), id: nil))
        XCTAssertThrowsError(try store.delete(id: original.id))
        XCTAssertEqual(try store.fetchAll(), [original])
    }

    func testLoadFailurePreservesLastSuccessfulSnapshot() throws {
        let (_, categories, store, food) = try fixture()
        _ = try store.save(draft(food), id: nil)
        let failingStore = FetchFailureStore(backing: store)
        let model = TransactionsViewModel(store: failingStore, categoryStore: categories)
        model.load()
        let previous = model.transactions
        failingStore.shouldFail = true
        model.load()
        XCTAssertTrue(model.loadFailed)
        XCTAssertEqual(model.transactions, previous)
        XCTAssertNotNil(model.errorMessage)
        failingStore.shouldFail = false
        model.load()
        XCTAssertFalse(model.loadFailed)
        XCTAssertNil(model.errorMessage)
    }
}

@MainActor
private final class FetchFailureStore: TransactionStore {
    let backing: any TransactionStore
    var shouldFail = false

    init(backing: any TransactionStore) { self.backing = backing }

    func fetchAll() throws -> [TransactionItem] {
        if shouldFail { throw CocoaError(.fileReadNoPermission) }
        return try backing.fetchAll()
    }

    func save(_ draft: TransactionDraft, id: UUID?) throws -> TransactionItem {
        try backing.save(draft, id: id)
    }

    func delete(id: UUID) throws { try backing.delete(id: id) }
}
