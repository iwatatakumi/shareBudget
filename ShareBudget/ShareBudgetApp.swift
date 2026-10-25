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
                // 高級感が出るように、いつも暗い画面（ダークモード）で表示し、
                // ボタンなどの強調する色を金色にします
                .preferredColorScheme(.dark)
                .tint(Theme.gold)
        }
    }
}
