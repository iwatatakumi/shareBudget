import SwiftUI

// 家計簿のメンバー・招待コード、項目と目標金額を設定する画面です。
struct SettingsView: View {
    @Environment(BudgetStore.self) private var store

    // 削除してよいか確認中の項目
    @State private var categoryToDelete: BudgetCategory?

    var body: some View {
        NavigationStack {
            List {
                householdSection
                categorySection

                Section {
                    Button("ログアウト", role: .destructive) {
                        Task { await store.signOut() }
                    }
                }
            }
            .navigationTitle("設定")
            .toolbar {
                EditButton()
            }
            .refreshable {
                await store.reload()
            }
            .confirmationDialog(
                "この項目を削除しますか？",
                isPresented: Binding(
                    get: { categoryToDelete != nil },
                    set: { if !$0 { categoryToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: categoryToDelete
            ) { category in
                Button("「\(category.name)」を削除", role: .destructive) {
                    Task { await store.deleteCategory(category) }
                    categoryToDelete = nil
                }
            } message: { _ in
                Text("この項目で入力した支出は消えずに「項目なし」になります。ルームメイトの画面からも消えます。")
            }
        }
    }

    private var householdSection: some View {
        Section {
            ForEach(store.members) { member in
                HStack {
                    Text(member.displayName)
                    if member.userId == store.userId {
                        Text("（自分）")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let household = store.household {
                HStack {
                    Text("招待コード")
                    Spacer()
                    Text(household.inviteCode)
                        .font(.body.monospaced().bold())
                        .textSelection(.enabled)
                }
                ShareLink(
                    item: "シェアバジェットの家計簿に参加してください。招待コード: \(household.inviteCode)"
                ) {
                    Label("招待コードを送る", systemImage: "square.and.arrow.up")
                }
            }
        } header: {
            Text("家計簿のメンバー")
        } footer: {
            Text("ルームメイトは、アプリで新規登録したあと「この家計簿に参加する」から招待コードを入れます。")
        }
    }

    private var categorySection: some View {
        Section {
            ForEach(store.categories) { category in
                NavigationLink {
                    CategoryEditView(category: category)
                } label: {
                    HStack {
                        Text(category.name)
                        Spacer()
                        Text(totalTarget(of: category).yenText)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                categoryToDelete = offsets.first.map { store.categories[$0] }
            }
            .onMove { source, destination in
                Task { await store.moveCategories(from: source, to: destination) }
            }

            NavigationLink {
                CategoryEditView(category: nil)
            } label: {
                Label("項目を追加", systemImage: "plus")
            }
        } header: {
            Text("項目と1か月の目標金額（全員の合計）")
        } footer: {
            Text("項目を押すと、人ごとの目標金額を決められます。右上の「編集」で並び替えができます。")
        }
    }

    private func totalTarget(of category: BudgetCategory) -> Int {
        store.members.reduce(0) { $0 + store.target(categoryId: category.id, userId: $1.userId) }
    }
}

#Preview {
    SettingsView()
        .environment(PreviewData.store)
}
