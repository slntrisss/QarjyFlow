import SwiftUI

struct PlanAllocationCreatorView: View {
    let groups: [PlanGroup]
    let categories: [CategoryItem]
    let income: Decimal
    let onSave: (PlanAllocation) async -> String?
    @Environment(\.dismiss) private var dismiss
    @State private var isFuturePurpose = false
    @State private var categoryID: UUID?
    @State private var purposeName = ""
    @State private var groupID: UUID
    @State private var usePercentage = false
    @State private var amountText = ""
    @State private var percentText = ""
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(groups: [PlanGroup], categories: [CategoryItem], income: Decimal,
         onSave: @escaping (PlanAllocation) async -> String?) {
        self.groups = groups; self.categories = categories; self.income = income; self.onSave = onSave
        _groupID = State(initialValue: groups.first?.id ?? UUID())
    }

    private var expenseCategories: [CategoryItem] {
        categories.filter { $0.kind == .expense && !$0.isArchived }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var rule: PlanAllocationRule? {
        guard let minor = AmountInputParsing.positiveMinorUnits(usePercentage ? percentText : amountText) else { return nil }
        let value = Decimal(minor) / 100
        return usePercentage ? (value <= 100 ? .percentage(value) : nil) : .fixed(value)
    }
    private var selectedCategory: CategoryItem? { expenseCategories.first { $0.id == categoryID } }
    private var canSave: Bool {
        groups.contains(where: { $0.id == groupID }) && rule != nil &&
        (isFuturePurpose ? !purposeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : selectedCategory != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Allocation for") {
                    Picker("Allocation target", selection: $isFuturePurpose) {
                        Text("Spending").tag(false); Text("Saving / Investing").tag(true)
                    }.pickerStyle(.segmented)
                    if isFuturePurpose {
                        TextField("Purpose, for example S&P 500", text: $purposeName)
                        Text("This creates a planning goal and does not require an income or expense category.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else if expenseCategories.isEmpty {
                        ContentUnavailableView("No expense categories", systemImage: "tag",
                                               description: Text("Create one in Home → Settings → Categories."))
                    } else {
                        Picker("Category", selection: $categoryID) {
                            Text("Choose a category").tag(nil as UUID?)
                            ForEach(expenseCategories) { Label($0.name, systemImage: $0.symbol).tag(Optional($0.id)) }
                        }
                    }
                    Picker("Plan section", selection: $groupID) {
                        ForEach(groups) { Label($0.name, systemImage: $0.symbol).tag($0.id) }
                    }
                }
                Section("Allocate by") {
                    Picker("Mode", selection: $usePercentage) {
                        Text("Fixed Amount").tag(false); Text("Percentage").tag(true)
                    }.pickerStyle(.segmented)
                    if usePercentage {
                        LabeledContent("Percent") {
                            AmountTextField(rawText: $percentText, placeholder: "10",
                                inputLabel: "Percentage of expected income", inputIdentifier: "plan.new.percentage")
                                .frame(minHeight: 44)
                            Text("%")
                        }
                    } else {
                        LabeledContent("Amount · KZT") {
                            AmountTextField(rawText: $amountText, inputIdentifier: "plan.new.amount")
                                .frame(minHeight: 44)
                        }
                    }
                    if let rule {
                        LabeledContent("Planned", value: rule.amount(income: income).tenge)
                    }
                }
                if let errorMessage {
                    Section { Label(errorMessage, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                }
                Section { Text("Saving and investment purposes are planning labels for now. Recording deposits and investment purchases will require the upcoming account and transfer flow.")
                    .font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Add Allocation").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(isSaving || !canSave)
                }
            }
        }.interactiveDismissDisabled(isSaving).tint(.green)
    }

    private func save() async {
        guard !isSaving, let rule else { return }
        isSaving = true; defer { isSaving = false }
        let name = isFuturePurpose ? purposeName.trimmingCharacters(in: .whitespacesAndNewlines) : selectedCategory!.name
        let allocation = PlanAllocation(id: UUID(), name: name,
            symbol: isFuturePurpose ? "shield.fill" : selectedCategory!.symbol,
            groupID: groupID, categoryID: isFuturePurpose ? nil : selectedCategory!.id,
            tracksContribution: isFuturePurpose, rule: rule)
        if let message = await onSave(allocation) { errorMessage = message }
        else { dismiss() }
    }
}

#Preview("Add allocation · expense category") {
    let item = CategoryItem(id: UUID(), name: "Housing", kind: .expense,
                            symbol: "house.fill", color: .blue, isArchived: false)
    PlanAllocationCreatorView(groups: PlanPreviewData.groups, categories: [item],
                              income: PlanPreviewData.income, onSave: { _ in nil })
}

#Preview("Add allocation · no categories") {
    PlanAllocationCreatorView(groups: PlanPreviewData.groups, categories: [],
                              income: PlanPreviewData.income, onSave: { _ in nil })
}
