import Foundation
import SwiftData
import XCTest
@testable import CategoriesCore

final class PlanPersistenceTests: XCTestCase {
    private func plan(month: PlanMonth, category: CategoryItem? = nil) -> MonthlyPlan {
        let group = PlanGroup(id: UUID(), name: "Needs", subtitle: "Essentials",
                              symbol: "house.fill", color: .blue)
        let allocation = category.map {
            PlanAllocation(id: UUID(), name: $0.name, symbol: $0.symbol, groupID: group.id,
                           categoryID: $0.id, tracksContribution: false, rule: .percentage(25))
        }
        return MonthlyPlan(id: UUID(), month: month,
                           incomeSources: [.init(id: UUID(), name: "Salary", amount: 800_000)],
                           groups: [group], allocations: allocation.map { [$0] } ?? [])
    }

    func testMonthlyPlanRoundTripsThroughActorStore() async throws {
        let database = try await LedgerDatabase.open(inMemory: true)
        let input = plan(month: PlanMonth(year: 2026, month: 9))
        let saved = try await database.savePlan(input)
        let loaded = try await database.fetchPlan(month: input.month)
        XCTAssertEqual(saved, input)
        XCTAssertEqual(loaded, input)
        XCTAssertEqual(loaded?.income, 800_000)
        XCTAssertEqual(loaded?.unallocated, 800_000)
    }

    func testPlanPersistsAcrossDiskContainerReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("plan.store")
        let input = plan(month: PlanMonth(year: 2027, month: 1))
        do {
            let database = try await LedgerDatabase.open(url: url)
            _ = try await database.savePlan(input)
        }
        let reopened = try await LedgerDatabase.open(url: url)
        let loaded = try await reopened.fetchPlan(month: input.month)
        XCTAssertEqual(loaded, input)
    }

    func testPopulatedUnversionedLedgerOpensWithVersionedMigrationPlan() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("legacy-full.store")
        let month = PlanMonth(year: 2026, month: 8)
        var expectedCategoryID: UUID!
        var expectedTransactionID: UUID!
        var expectedPlanID: UUID!

        try autoreleasepool {
            let legacySchema = Schema([
                CategoryRecord.self, TransactionRecord.self, MonthlyPlanRecord.self,
                PlannedIncomeRecord.self, PlanGroupRecord.self, PlanAllocationRecord.self
            ])
            let configuration = ModelConfiguration(
                schema: legacySchema, url: url, cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: legacySchema, configurations: [configuration])
            let categories = CategoryRepository(container: container)
            var categoryDraft = CategoryDraft()
            categoryDraft.name = "Rent"
            let category = try categories.save(categoryDraft, id: nil)
            expectedCategoryID = category.id

            var transactionDraft = TransactionDraft()
            transactionDraft.amountText = "300000"
            transactionDraft.categoryID = category.id
            let transaction = try TransactionRepository(container: container).save(transactionDraft, id: nil)
            expectedTransactionID = transaction.id

            let value = plan(month: month, category: category)
            _ = try PlanRepository(container: container).save(value)
            expectedPlanID = value.id
        }

        let migrated = try await LedgerDatabase.open(url: url)
        let snapshot = try await migrated.fetchSnapshot()
        let loadedPlan = try await migrated.fetchPlan(month: month)
        XCTAssertEqual(snapshot.categories.first?.id, expectedCategoryID)
        XCTAssertEqual(snapshot.transactions.first?.id, expectedTransactionID)
        XCTAssertEqual(loadedPlan?.id, expectedPlanID)
        XCTAssertEqual(loadedPlan?.allocations.first?.categoryID, expectedCategoryID)
        XCTAssertEqual(loadedPlan?.income, 800_000)
    }

    func testCategoryReferencedByPlanCannotBeDeletedUntilAllocationIsRemoved() async throws {
        let database = try await LedgerDatabase.open(inMemory: true)
        var categoryDraft = CategoryDraft(); categoryDraft.name = "Housing"
        let category = try await database.saveCategory(categoryDraft, id: nil)
        var value = plan(month: PlanMonth(year: 2026, month: 10), category: category)
        _ = try await database.savePlan(value)

        do {
            try await database.deleteCategory(id: category.id)
            XCTFail("Expected used category deletion to fail")
        } catch let error as CategoryError {
            XCTAssertEqual(error.localizedDescription, CategoryError.inUse.localizedDescription)
        }

        value.allocations = []
        _ = try await database.savePlan(value)
        try await database.deleteCategory(id: category.id)
        let remainingCategories = try await database.fetchCategories()
        XCTAssertTrue(remainingCategories.isEmpty)
    }

    @MainActor
    func testViewModelRestoresSavedPlan() async throws {
        let store = PreviewPlanStore()
        let month = PlanMonth(year: 2026, month: 11)
        let first = PlanViewModel(store: store, month: month)
        await first.load(); await first.createPlan()
        var income = PlannedIncomeDraft(); income.name = "Salary"; income.amountText = "500000"
        let result = await first.saveIncome(income, id: nil)
        XCTAssertNil(result)

        let reopened = PlanViewModel(store: store, month: month)
        await reopened.load()
        XCTAssertTrue(reopened.hasPlan)
        XCTAssertEqual(reopened.income, 500_000)
        XCTAssertEqual(reopened.groups.count, 4)
    }
}
