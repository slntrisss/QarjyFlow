import SwiftUI

struct PlanOverviewView: View {
    let monthTitle: String
    let progress: PlanProgress
    let incomeSourceCount: Int
    let groups: [PlanGroup]
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
                PlanIncomeCard(expected: progress.expectedIncome, recorded: progress.recordedIncome,
                               sourceCount: incomeSourceCount, onEdit: onEditIncome)
                PlanAllocationSummary(income: progress.expectedIncome,
                                      allocated: progress.allocations.reduce(0) { $0 + $1.planned })
                if progress.unplannedSpending > 0 {
                    HStack {
                        Label("Unplanned spending", systemImage: "exclamationmark.triangle.fill")
                        Spacer()
                        Text(progress.unplannedSpending.tenge).fontWeight(.semibold)
                    }
                    .foregroundStyle(.orange).cardStyle()
                }
                HStack {
                    Text("Your allocations").font(.title3.bold())
                    Spacer()
                    Button("Add", systemImage: "plus", action: onAddAllocation)
                }
                ForEach(groups) { group in
                    PlanGroupSection(group: group,
                                     allocations: progress.allocations.filter { $0.allocation.groupID == group.id },
                                     onEdit: onEdit, onDelete: onDelete)
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
    let progress = PlanProgressCalculator().calculate(plan: PlanPreviewData.plan, transactions: [])
    NavigationStack {
        PlanOverviewView(monthTitle: PlanPreviewData.plan.month.title,
                         progress: progress, incomeSourceCount: 2, groups: PlanPreviewData.groups,
                         onEdit: { _ in }, onDelete: { _ in }, onEditIncome: {}, onAddAllocation: {})
    }
}

#Preview("Plan overview · accessibility text") {
    let progress = PlanProgressCalculator().calculate(plan: PlanPreviewData.plan, transactions: [])
    NavigationStack {
        PlanOverviewView(monthTitle: PlanPreviewData.plan.month.title,
                         progress: progress, incomeSourceCount: 2, groups: PlanPreviewData.groups,
                         onEdit: { _ in }, onDelete: { _ in }, onEditIncome: {}, onAddAllocation: {})
    }.environment(\.dynamicTypeSize, .accessibility2)
}
