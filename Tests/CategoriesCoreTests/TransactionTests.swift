import Foundation
import SwiftData
import XCTest
@testable import CategoriesCore

@MainActor
final class TransactionTests: XCTestCase {
    private func fixture() throws -> (ModelContainer, CategoryRepository, TransactionRepository, CategoryItem) {
        let container = try AppDatabase.makeContainer(inMemory: true)
        let categories = CategoryRepository(container: container)
        let transactions = TransactionRepository(container: container)
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
            let categories = CategoryRepository(container: container)
            let category = try XCTUnwrap(categories.fetchAll().first)
            XCTAssertEqual(category.id, categoryID)
            XCTAssertEqual(category.name, "Existing category")
            return try TransactionRepository(container: container).save(draft(category), id: nil).id
        }
        try autoreleasepool {
            let container = try AppDatabase.makeContainer(url: url)
            let item = try XCTUnwrap(TransactionRepository(container: container).fetchAll().first)
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

    func testTransactionDateFiltersUseInclusiveCalendarDays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let formatter = ISO8601DateFormatter()
        let now = formatter.date(from: "2026-09-06T12:00:00Z")!
        let from = formatter.date(from: "2026-08-15T00:00:00Z")!
        let to = formatter.date(from: "2026-08-20T00:00:00Z")!
        // Rolling seven-day boundary requested by the product: August 30 through now.
        XCTAssertTrue(TransactionDateFilter.last7Days.includes(
            formatter.date(from: "2026-08-30T00:00:00Z")!, from: from, to: to, now: now, calendar: calendar))
        XCTAssertFalse(TransactionDateFilter.last7Days.includes(
            formatter.date(from: "2026-08-29T23:59:59Z")!, from: from, to: to, now: now, calendar: calendar))
        XCTAssertTrue(TransactionDateFilter.lastMonth.includes(
            formatter.date(from: "2026-08-06T00:00:00Z")!, from: from, to: to, now: now, calendar: calendar))
        XCTAssertFalse(TransactionDateFilter.lastMonth.includes(
            formatter.date(from: "2026-08-05T23:59:59Z")!, from: from, to: to, now: now, calendar: calendar))
        XCTAssertTrue(TransactionDateFilter.specifiedPeriod.includes(
            formatter.date(from: "2026-08-20T23:59:59Z")!, from: from, to: to, now: now, calendar: calendar))
        XCTAssertFalse(TransactionDateFilter.specifiedPeriod.includes(
            formatter.date(from: "2026-08-21T00:00:00Z")!, from: from, to: to, now: now, calendar: calendar))
    }

    @MainActor
    func testSavedIncomeAppearsInReloadedHomeSummary() async throws {
        let database = try await LedgerDatabase.open(inMemory: true)
        let categoryStore = SwiftDataCategoryStore(database: database)
        var categoryDraft = CategoryDraft()
        categoryDraft.name = "Salary"
        categoryDraft.kind = .income
        let salary = try await categoryStore.save(categoryDraft, id: nil)

        let store = SwiftDataTransactionStore(database: database)
        let activity = TransactionsViewModel(store: store)
        await activity.load()
        var income = TransactionDraft()
        income.amountText = "1032000"
        income.kind = .income
        income.categoryID = salary.id
        income.date = Date()
        try await activity.save(income, id: nil)

        let reopenedHome = TransactionsViewModel(store: store)
        await reopenedHome.load()
        let summary = TransactionSummary(transactions: reopenedHome.transactions)
        XCTAssertEqual(summary.income, 1_032_000)
        XCTAssertEqual(summary.expense, 0)
        XCTAssertEqual(summary.net, 1_032_000)
        XCTAssertEqual(summary.count, 1)
    }

    func testViewModelUpdatesAfterSaveDeleteAndNewCategoryCreation() async throws {
        let database = try await LedgerDatabase.open(inMemory: true)
        let categories = SwiftDataCategoryStore(database: database)
        let store = SwiftDataTransactionStore(database: database)
        var foodDraft = CategoryDraft()
        foodDraft.name = "Food"
        let food = try await categories.save(foodDraft, id: nil)
        let model = TransactionsViewModel(store: store)
        model.dateFilter = .specifiedPeriod
        model.customFromDate = .distantPast
        model.customToDate = Date()
        await model.load()
        try await model.save(draft(food), id: nil)
        var newCategory = CategoryDraft()
        newCategory.name = "Books"
        let books = try await categories.save(newCategory, id: nil)
        await model.load()
        XCTAssertEqual(model.categories.count, 2)
        try await model.save(draft(books), id: nil)
        model.searchText = "Books"
        XCTAssertEqual(model.visibleTransactions.count, 1)
        model.filter = .income
        XCTAssertTrue(model.visibleTransactions.isEmpty)
        model.filter = nil
        let bookTransaction = try XCTUnwrap(model.visibleTransactions.first)
        await model.delete(bookTransaction)
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
            let category = try CategoryRepository(container: container).save(categoryDraft, id: nil)
            let original = try TransactionRepository(container: container).save(draft(category), id: nil)
            return (category, original)
        }
        let schema = AppDatabase.schema
        let config = ModelConfiguration(schema: schema, url: url, allowsSave: false, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let store = TransactionRepository(container: container)
        XCTAssertThrowsError(try store.save(draft(category, amount: "900"), id: original.id))
        XCTAssertThrowsError(try store.save(draft(category), id: nil))
        XCTAssertThrowsError(try store.delete(id: original.id))
        XCTAssertEqual(try store.fetchAll(), [original])
    }

    func testLoadFailurePreservesLastSuccessfulSnapshot() async throws {
        let database = try await LedgerDatabase.open(inMemory: true)
        let categories = SwiftDataCategoryStore(database: database)
        let store = SwiftDataTransactionStore(database: database)
        var foodDraft = CategoryDraft()
        foodDraft.name = "Food"
        let food = try await categories.save(foodDraft, id: nil)
        _ = try await store.save(draft(food), id: nil)
        let failingStore = FetchFailureStore(backing: store)
        let model = TransactionsViewModel(store: failingStore)
        await model.load()
        let previous = model.transactions
        failingStore.shouldFail = true
        await model.load()
        XCTAssertTrue(model.loadFailed)
        XCTAssertEqual(model.transactions, previous)
        XCTAssertNotNil(model.errorMessage)
        failingStore.shouldFail = false
        await model.load()
        XCTAssertFalse(model.loadFailed)
        XCTAssertNil(model.errorMessage)
    }
}

@MainActor
private final class FetchFailureStore: TransactionStore {
    let backing: any TransactionStore
    var shouldFail = false

    init(backing: any TransactionStore) { self.backing = backing }

    func fetchSnapshot() async throws -> LedgerSnapshot {
        if shouldFail { throw CocoaError(.fileReadNoPermission) }
        return try await backing.fetchSnapshot()
    }

    func fetchAll() async throws -> [TransactionItem] {
        if shouldFail { throw CocoaError(.fileReadNoPermission) }
        return try await backing.fetchAll()
    }

    func save(_ draft: TransactionDraft, id: UUID?) async throws -> TransactionItem {
        try await backing.save(draft, id: id)
    }

    func delete(id: UUID) async throws { try await backing.delete(id: id) }
}

extension TransactionTests {
    func testConcurrentDeleteAndTransactionSaveCannotCreateOrphan() async throws {
        let database = try await LedgerDatabase.open(inMemory: true)
        for index in 0..<20 {
            var categoryDraft = CategoryDraft()
            categoryDraft.name = "Race \(index)"
            let category = try await database.saveCategory(categoryDraft, id: nil)
            let transactionDraft = draft(category)
            async let deletion: Void? = try? database.deleteCategory(id: category.id)
            async let insertion: TransactionItem? = try? database.saveTransaction(transactionDraft, id: nil)
            _ = await (deletion, insertion)
            let snapshot = try await database.fetchSnapshot()
            let categoryIDs = Set(snapshot.categories.map(\.id))
            XCTAssertTrue(snapshot.transactions.allSatisfy { categoryIDs.contains($0.categoryID) })
        }
    }

    func testConcurrentDuplicateCategoryCreationHasOneWinner() async throws {
        let database = try await LedgerDatabase.open(inMemory: true)
        var draft = CategoryDraft()
        draft.name = "Food"
        let input = draft
        async let first: CategoryItem? = try? database.saveCategory(input, id: nil)
        async let second: CategoryItem? = try? database.saveCategory(input, id: nil)
        let results = await [first, second]
        XCTAssertEqual(results.compactMap { $0 }.count, 1)
        let categories = try await database.fetchCategories()
        XCTAssertEqual(categories.count, 1)
    }
}
