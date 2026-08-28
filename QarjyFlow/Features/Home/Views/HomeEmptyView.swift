import SwiftUI

struct HomeEmptyView: View {
    let onManageCategories: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Make room for your first expense", systemImage: "leaf")
        } description: {
            Text("Start by creating your categories. Transaction entry is the next milestone; no sample balances are mixed with your data.")
        } actions: {
            Button("Manage Categories", action: onManageCategories)
                .buttonStyle(.borderedProminent)
            NavigationLink("View Sample Dashboard") {
                HomeView(snapshot: .demo)
            }
            .buttonStyle(.bordered)
        }
        .navigationTitle("QarjyFlow")
    }
}

#Preview("Home · getting started") {
    NavigationStack { HomeEmptyView(onManageCategories: {}) }
        .tint(.green)
}
