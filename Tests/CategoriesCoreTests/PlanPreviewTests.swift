import XCTest
@testable import CategoriesCore

final class PlanPreviewTests: XCTestCase {
    func testPercentageRebasesWhileFixedAllocationStaysUnchanged() {
        let fixed = PlanAllocationRule.fixed(250_000)
        let percentage = PlanAllocationRule.percentage(30)
        XCTAssertEqual(fixed.amount(income: 800_000), 250_000)
        XCTAssertEqual(fixed.amount(income: 1_000_000), 250_000)
        XCTAssertEqual(percentage.amount(income: 800_000), 240_000)
        XCTAssertEqual(percentage.amount(income: 1_000_000), 300_000)
    }

    func testPrototypeRoundsPercentageToMinorUnitsWithoutFloatingPoint() {
        XCTAssertEqual(PlanAllocationRule.percentage(50).amount(income: Decimal(string: "0.01")!), Decimal(string: "0.01"))
        XCTAssertEqual(PlanAllocationRule.percentage(30).amount(income: Decimal(string: "100.01")!), 30)
        XCTAssertEqual(PlanAllocationRule.percentage(30).amount(income: 0), 0)
    }

    @MainActor
    func testSampleEditsUpdateTotalWithoutChangingOtherAllocations() async throws {
        let model = PlanViewModel()
        XCTAssertEqual(model.income - model.allocated, 30_000)
        let rent = try XCTUnwrap(model.allocations.first)
        await model.updateAllocation(id: rent.id, rule: .fixed(300_000), groupID: rent.groupID)
        XCTAssertEqual(model.income - model.allocated, -20_000)
        XCTAssertEqual(model.allocations[3].rule, .percentage(30))
        XCTAssertEqual(model.groups.map(\.name), ["Needs", "Future", "Lifestyle", "Free"])
    }

    @MainActor
    func testPlanSectionsCanBeAddedRenamedAndReordered() async throws {
        let model = PlanViewModel()
        var draft = PlanGroupDraft()
        draft.name = "Giving"
        draft.subtitle = "Gifts and donations"
        draft.symbol = "gift.fill"
        draft.color = .pink
        let addResult = await model.saveGroup(draft, id: nil)
        XCTAssertNil(addResult)
        let giving = try XCTUnwrap(model.groups.last)

        draft.name = "Generosity"
        let renameResult = await model.saveGroup(draft, id: giving.id)
        XCTAssertNil(renameResult)
        XCTAssertEqual(model.groups.last?.name, "Generosity")
        await model.moveGroups(from: IndexSet(integer: model.groups.count - 1), to: 0)
        XCTAssertEqual(model.groups.first?.id, giving.id)
    }

    @MainActor
    func testDeletingSectionCascadesAllocationsBackToUnallocated() async {
        let model = PlanViewModel()
        let beforeAllocated = model.allocated
        let needsAmount = model.allocatedAmount(inGroupIDs: [PlanPreviewData.needsID])
        let needsCount = model.allocations.filter { $0.groupID == PlanPreviewData.needsID }.count
        XCTAssertGreaterThan(needsCount, 0)

        await model.deleteGroups(ids: [PlanPreviewData.needsID])

        XCTAssertFalse(model.groups.contains { $0.id == PlanPreviewData.needsID })
        XCTAssertFalse(model.allocations.contains { $0.groupID == PlanPreviewData.needsID })
        XCTAssertEqual(model.allocated, beforeAllocated - needsAmount)
        XCTAssertEqual(model.income - model.allocated, 30_000 + needsAmount)
    }

    @MainActor
    func testDeletingAllocationReturnsOnlyItsAmountToUnallocated() async throws {
        let model = PlanViewModel()
        let allocation = try XCTUnwrap(model.allocations.first)
        let amount = allocation.rule.amount(income: model.income)
        let beforeAllocated = model.allocated
        let beforeCount = model.allocations.count

        await model.deleteAllocation(id: allocation.id)

        XCTAssertEqual(model.allocations.count, beforeCount - 1)
        XCTAssertEqual(model.allocated, beforeAllocated - amount)
        XCTAssertEqual(model.groups.count, 4)
    }

    @MainActor
    func testPlanSectionNamesAreRequiredAndUniqueIgnoringCase() async {
        let model = PlanViewModel()
        var draft = PlanGroupDraft()
        let invalidResult = await model.saveGroup(draft, id: nil)
        XCTAssertNotNil(invalidResult)
        draft.name = "needs"
        let duplicateResult = await model.saveGroup(draft, id: nil)
        XCTAssertNotNil(duplicateResult)
        XCTAssertEqual(model.groups.count, 4)
    }

    @MainActor
    func testAllocationCanMoveToAnotherSectionWithoutChangingItsAmount() async throws {
        let model = PlanViewModel()
        let allocation = try XCTUnwrap(model.allocations.first)
        let amount = allocation.rule.amount(income: model.income)
        await model.updateAllocation(id: allocation.id, rule: allocation.rule, groupID: PlanPreviewData.lifestyleID)
        let moved = try XCTUnwrap(model.allocations.first { $0.id == allocation.id })
        XCTAssertEqual(moved.groupID, PlanPreviewData.lifestyleID)
        XCTAssertEqual(moved.rule.amount(income: model.income), amount)
        XCTAssertEqual(model.allocated, 770_000)
    }
}

extension PlanPreviewTests {
    @MainActor
    func testAddingIncomeSourceRecalculatesPercentageButNotFixedAllocations() async throws {
        let model = PlanViewModel()
        let rent = try XCTUnwrap(model.allocations.first { $0.name == "Rent" })
        let investment = try XCTUnwrap(model.allocations.first { $0.name == "Investments" })
        let rentBefore = rent.rule.amount(income: model.income)
        let investmentBefore = investment.rule.amount(income: model.income)

        var draft = PlannedIncomeDraft()
        draft.name = "Rental income"
        draft.amountText = "200000"
        let incomeResult = await model.saveIncome(draft, id: nil)
        XCTAssertNil(incomeResult)

        XCTAssertEqual(model.income, 1_000_000)
        XCTAssertEqual(rent.rule.amount(income: model.income), rentBefore)
        XCTAssertEqual(investment.rule.amount(income: model.income), 300_000)
        XCTAssertNotEqual(investment.rule.amount(income: model.income), investmentBefore)
        XCTAssertEqual(model.allocated, 840_000)
        XCTAssertEqual(model.income - model.allocated, 160_000)
    }

    @MainActor
    func testExpectedIncomeCanBeEditedDeletedAndCannotDuplicateNames() async throws {
        let model = PlanViewModel()
        let salary = try XCTUnwrap(model.incomeSources.first)
        var edit = PlannedIncomeDraft(source: salary)
        edit.amountText = "900000"
        let editResult = await model.saveIncome(edit, id: salary.id)
        XCTAssertNil(editResult)
        XCTAssertEqual(model.income, 1_000_000)

        var duplicate = PlannedIncomeDraft()
        duplicate.name = "SALARY"
        duplicate.amountText = "1"
        let duplicateResult = await model.saveIncome(duplicate, id: nil)
        XCTAssertNotNil(duplicateResult)

        let freelance = try XCTUnwrap(model.incomeSources.first { $0.name == "Freelance" })
        await model.deleteIncome(id: freelance.id)
        XCTAssertEqual(model.income, 900_000)
        XCTAssertEqual(model.incomeSources.count, 1)
    }
}
