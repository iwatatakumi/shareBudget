import SwiftData
import SwiftUI

// 画面下のタブ（切り替えボタン）をまとめる画面です。
// タブを押すと、それぞれの画面に切り替わります。
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }

            AddExpenseView()
                .tabItem { Label("入力", systemImage: "plus.circle") }

            ExpenseListView()
                .tabItem { Label("一覧", systemImage: "list.bullet") }

            TravelFundView()
                .tabItem { Label("旅行資金", systemImage: "airplane") }

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .task {
            // 初めて開いたときに「食費」などの項目を用意します。
            BudgetCategory.insertDefaultsIfNeeded(into: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container)
}
