import SwiftUI

struct PlanOverviewView: View {
    let monthTitle: String
    let income: Decimal
    let incomeSourceCount: Int
    let groups: [PlanGroup]
    let allocations: [PlanAllocation]
    let onEdit: (PlanAllocation) -> Void
    let onDelete: (PlanAllocation) -> Void
    let onEditIncome: () -> Void
    let onAddAllocation: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(monthTitle).font(.title2.bold())
                    Text("Tap an allocation to edit its amount or move it to another section. Use the toolbar to customize sections.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                PlanIncomeCard(income: income, sourceCount: incomeSourceCount, onEdit: onEditIncome)
                PlanAllocationSummary(income: income,
                                      allocated: allocations.reduce(0) { $0 + $1.rule.amount(income: income) })
                HStack {
                    Text("Your allocations").font(.title3.bold())
                    Spacer()
                    Button("Add", systemImage: "plus", action: onAddAllocation)
                }
                ForEach(groups) { group in
                    PlanGroupSection(group: group,
                                     allocations: allocations.filter { $0.groupID == group.id },
                                     income: income, onEdit: onEdit, onDelete: onDelete)
                }
                Text("Planning money does not spend or transfer it. Actual spending will connect to Activity later.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("My Plan").navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Plan overview · customizable sections") {
    NavigationStack {
        PlanOverviewView(monthTitle: PlanPreviewData.plan.month.title,
                         income: PlanPreviewData.income, incomeSourceCount: 2, groups: PlanPreviewData.groups,
                         allocations: PlanPreviewData.allocations,
                         onEdit: { _ in }, onDelete: { _ in }, onEditIncome: {}, onAddAllocation: {})
    }
}

#Preview("Plan overview · accessibility text") {
    NavigationStack {
        PlanOverviewView(monthTitle: PlanPreviewData.plan.month.title,
                         income: PlanPreviewData.income, incomeSourceCount: 2, groups: PlanPreviewData.groups,
                         allocations: PlanPreviewData.allocations,
                         onEdit: { _ in }, onDelete: { _ in }, onEditIncome: {}, onAddAllocation: {})
    }.environment(\.dynamicTypeSize, .accessibility2)
}
