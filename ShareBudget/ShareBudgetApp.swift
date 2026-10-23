import SwiftUI

// アプリの入り口です。アプリを起動すると、まずここが動きます。
@main
struct ShareBudgetApp: App {
    // アプリ全体で1つだけ使うデータの係
    @State private var store = BudgetStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
