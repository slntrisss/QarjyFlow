import SwiftUI

struct ContentView: View {
    let stores: AppStores
    @State private var model: TransactionsViewModel
    @State private var selection = 0
    @Environment(\.scenePhase) private var scenePhase

    init(stores: AppStores) {
        self.stores = stores
        _model = State(initialValue: stores.transactionModel())
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeLedgerView(model: model)
            }
            .tabItem { Label("Home", systemImage: "house") }.tag(0)
            NavigationStack {
                ActivityView(model: model, onManageCategories: { selection = 2 })
            }
            .tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }.tag(1)
            NavigationStack { CategoriesView(store: stores.categories) }
                .tabItem { Label("Categories", systemImage: "tag") }.tag(2)
        }
        .tint(.green)
        .task { model.load() }
        .onChange(of: selection) { _, _ in model.load() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { model.load() } }
        .alert("Transactions", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Reload") { model.load() }
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

#Preview("App · local ledger") { ContentView(stores: TransactionPreviewData.stores()) }
