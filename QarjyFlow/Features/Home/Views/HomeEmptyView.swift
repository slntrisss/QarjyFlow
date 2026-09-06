import SwiftUI

struct HomeEmptyView: View {

    var body: some View {
        ContentUnavailableView {
            Label("Make room for your first expense", systemImage: "leaf")
        } description: {
            Text("Start by creating your categories, then record income and expenses in Activity. No sample balances are mixed with your data.")
        }
        .navigationTitle("QarjyFlow")
    }
}

#Preview("Home · getting started") {
    NavigationStack { HomeEmptyView() }
        .tint(.green)
}
