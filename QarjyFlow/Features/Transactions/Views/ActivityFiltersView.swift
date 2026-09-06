import SwiftUI

struct ActivityFiltersView: View {
    @Bindable var model: TransactionsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Time period") {
                    Picker("Time period", selection: $model.dateFilter) {
                        ForEach(TransactionDateFilter.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    if model.dateFilter == .specifiedPeriod {
                        DatePicker("From", selection: $model.customFromDate,
                                   in: ...Date(), displayedComponents: .date)
                        DatePicker("To", selection: $model.customToDate,
                                   in: ...Date(), displayedComponents: .date)
                    }
                }
                Section("Category") {
                    Picker("Category", selection: $model.categoryFilterID) {
                        Text("All categories").tag(nil as UUID?)
                        ForEach(model.filterCategories) { category in
                            Label(category.name, systemImage: category.symbol).tag(Optional(category.id))
                        }
                    }
                }
                Section {
                    Text("Filters change what Activity displays. Every transaction remains stored on this iPhone.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Activity Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(.green)
    }
}

#Preview("Activity filters · specified period") {
    ActivityFiltersView(model: {
        let model = TransactionPreviewData.model()
        model.dateFilter = .specifiedPeriod
        return model
    }())
}
