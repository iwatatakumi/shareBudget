import SwiftUI

// ログインしているか、家計簿に参加しているかで、最初に出す画面を切り替えます。
struct RootView: View {
    @Environment(BudgetStore.self) private var store

    var body: some View {
        Group {
            switch store.phase {
            case .notConfigured:
                NotConfiguredView()
            case .loading:
                ProgressView("読み込み中…")
            case .signedOut:
                AuthView()
            case .needsHousehold:
                HouseholdSetupView()
            case .ready:
                MainTabView()
            }
        }
        .task {
            await store.start()
        }
        .alert(
            "うまくいきませんでした",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

// SupabaseConfig.swift がまだ書きかえられていないときの画面です。
private struct NotConfiguredView: View {
    var body: some View {
        ContentUnavailableView(
            "Supabaseの設定がまだです",
            systemImage: "gearshape.2",
            description: Text("Xcodeで「Supabase」フォルダの SupabaseConfig.swift を開き、Project URL と publishable key を書きかえてください。")
        )
    }
}

// 画面下のタブ（切り替えボタン）をまとめる画面です。
struct MainTabView: View {
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
    }
}

#Preview {
    MainTabView()
        .environment(PreviewData.store)
}
