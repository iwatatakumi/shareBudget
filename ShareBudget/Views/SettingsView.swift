import SwiftUI

// 家計簿のメンバー・家計簿ID、項目と目標金額を設定する画面です。
struct SettingsView: View {
    @Environment(BudgetStore.self) private var store

    // 削除してよいか確認中の項目
    @State private var categoryToDelete: BudgetCategory?

    var body: some View {
        NavigationStack {
            List {
                householdSection
                if store.isOwner {
                    Section {
                        NavigationLink("参加用パスワードを変える") {
                            PasswordChangeView()
                        }
                    } header: {
                        Text("管理者")
                    } footer: {
                        Text("変えたあとは、新しいパスワードでしか参加できません。すでに参加している人はそのまま使えます。")
                    }
                }
                categorySection
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
                    Text("家計簿ID")
                    Spacer()
                    Text(household.inviteCode)
                        .font(.body.monospaced().bold())
                        .textSelection(.enabled)
                }
                ShareLink(
                    item: "シェアバジェットの家計簿に参加してください。家計簿ID: \(household.inviteCode)（パスワードは別に伝えます）"
                ) {
                    Label("家計簿IDを送る", systemImage: "square.and.arrow.up")
                }
            }
        } header: {
            Text("家計簿のメンバー")
        } footer: {
            Text("ルームメイトは、アプリを開いて「この家計簿に参加する」に家計簿IDとパスワードを入れます。パスワードは、家計簿IDとは別に口頭などで伝えてください。")
        }
    }

    private var categorySection: some View {
        Section {
            ForEach(store.categories) { category in
                NavigationLink {
                    CategoryEditView(category: category)
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(store.categoryColor(category.id))
                            .frame(width: 10, height: 10)
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

// 管理者が参加用パスワードを変える画面です。
private struct PasswordChangeView: View {
    @Environment(BudgetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var isWorking = false

    var body: some View {
        Form {
            Section {
                SecureField("新しいパスワード（4文字以上）", text: $password)
            }
            Section {
                Button("変える") {
                    Task {
                        isWorking = true
                        if await store.changePassword(password) {
                            dismiss()
                        }
                        isWorking = false
                    }
                }
                .disabled(password.count < 4 || isWorking)
            }
        }
        .navigationTitle("参加用パスワード")
    }
}

#Preview {
    SettingsView()
        .environment(PreviewData.store)
}
