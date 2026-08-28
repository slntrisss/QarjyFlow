import SwiftUI

struct ContentView: View {
    let store: any CategoryStore
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeEmptyView { selection = 1 }
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(0)

            NavigationStack {
                CategoriesView(store: store)
            }
            .tabItem { Label("Categories", systemImage: "tag") }
            .tag(1)
        }
        .tint(.green)
    }
}

#Preview("App · local category flow") {
    ContentView(store: CategoryPreviewData.makeStore())
}
