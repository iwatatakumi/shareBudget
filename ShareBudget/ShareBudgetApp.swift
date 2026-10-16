import SwiftData
import SwiftUI

// アプリの入り口です。アプリを起動すると、まずここが動きます。
@main
struct ShareBudgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // 支出と項目をiPhoneの中に保存できるようにします。
        .modelContainer(for: [Expense.self, BudgetCategory.self])
    }
}
