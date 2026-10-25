import SwiftUI

// ログインしているか、家計簿に参加しているかで、最初に出す画面を切り替えます。
struct RootView: View {
    @Environment(BudgetStore.self) private var store
    /// 起動時のタイトル演出（SplashView）を出しているか
    @State private var showsSplash = true

    var body: some View {
        Group {
            switch store.phase {
            case .notConfigured:
                NotConfiguredView()
            case .loading:
                ProgressView("読み込み中…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .connectionFailed:
                ConnectionFailedView()
            case .needsHousehold:
                HouseholdSetupView()
            case .ready:
                MainTabView()
            }
        }
        .background(LuxuryBackground())
        // 起動時のタイトル演出を、いちばん上に重ねて出します
        .overlay {
            if showsSplash {
                SplashView()
                    .transition(.opacity.combined(with: .scale(scale: 1.08)))
            }
        }
        .task {
            await store.start()
        }
        .task {
            // 演出を最後まで見せるため、2.4秒待ってから消します（その間に裏でデータを読み込みます）
            try? await Task.sleep(for: .seconds(2.4))
            withAnimation(.easeInOut(duration: 0.6)) {
                showsSplash = false
            }
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

// Supabaseにつながらなかったときの画面です。
private struct ConnectionFailedView: View {
    @Environment(BudgetStore.self) private var store

    var body: some View {
        ContentUnavailableView {
            Label("つながりませんでした", systemImage: "wifi.exclamationmark")
        } description: {
            VStack(spacing: 12) {
                Text("インターネットにつながっているか確かめてください。\nはじめて使うときは、Supabaseの「Allow anonymous sign-ins」がオンになっている必要があります。")
                if let detail = store.connectionError {
                    Text("くわしい内容: \(detail)")
                        .font(.footnote)
                        .textSelection(.enabled)
                }
            }
        } actions: {
            Button("もう一度試す") {
                Task { await store.start() }
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(.black)
        }
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
