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
                HomeLedgerView(store: stores.home)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            NavigationLink {
                                SettingsView(categoryStore: stores.categories)
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.title3.weight(.semibold))
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("Settings")
                        }
                    }
            }
            .tabItem { Label("Home", systemImage: "house") }.tag(0)
            NavigationStack {
                ActivityView(model: model, categoryStore: stores.categories)
            }
            .tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }.tag(1)
            NavigationStack {
                PlanView(store: stores.plans, goalStore: stores.goals, categories: model.categories,
                         transactions: model.transactions)
            }
                .tabItem { Label("Plan", systemImage: "chart.pie") }.tag(2)
            NavigationStack {
                AnalyticsView(store: stores.home)
            }
            .tabItem { Label("Analytics", systemImage: "chart.bar") }.tag(3)
        }
        .tint(.green)
        // Tab switches and scene activation are cheap triggers: coalesce them so
        // flipping tabs doesn't re-fetch the whole ledger each time.
        .onChange(of: selection) { _, tab in
            // Activity owns its initial task. Plan still consumes this shared model.
            if tab == 2 { Task { await model.load(minInterval: 2) } }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, selection != 0 { Task { await model.load(minInterval: 2) } }
        }
        .alert("Transactions", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("Reload") { Task { await model.load() } }
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

#Preview("App · local ledger") { ContentView(stores: TransactionPreviewData.stores()) }
