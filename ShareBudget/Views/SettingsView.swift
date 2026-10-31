import SwiftUI

// 家計簿のメンバー・家計簿ID、項目と目標金額を設定する画面です。
struct SettingsView: View {
    @Environment(BudgetStore.self) private var store

    // 削除してよいか確認中の項目
    @State private var categoryToDelete: BudgetCategory?
    // アカウントの削除を確認中か
    @State private var confirmsAccountDeletion = false
    @State private var isDeletingAccount = false

    /// プライバシーポリシーのページ（GitHub Pages で公開します。docs/privacy.html）
    private static let privacyPolicyURL = URL(string: "https://iwatatakumi.github.io/shareBudget/privacy.html")!

    var body: some View {
        NavigationStack {
            LuxuryList {
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
                accountSection
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
            .alert("アカウントとデータを削除しますか？", isPresented: $confirmsAccountDeletion) {
                Button("削除する", role: .destructive) {
                    isDeletingAccount = true
                    Task {
                        await store.deleteAccount()
                        isDeletingAccount = false
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(store.members.count > 1
                    ? "あなたの目標金額と支出の配分が削除され、家計簿から抜けます。家計簿と入力した支出は、ほかのメンバーのために残ります。この操作は元に戻せません。"
                    : "家計簿と、支出・項目・臨時収入などのデータがすべて削除されます。この操作は元に戻せません。")
            }
        }
    }

    // プライバシーポリシーと、アカウントの削除です。
    private var accountSection: some View {
        Section {
            Link(destination: Self.privacyPolicyURL) {
                Label("プライバシーポリシー", systemImage: "hand.raised")
            }
            Button(role: .destructive) {
                confirmsAccountDeletion = true
            } label: {
                HStack {
                    Label("アカウントとデータを削除", systemImage: "trash")
                    if isDeletingAccount {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isDeletingAccount)
        } header: {
            Text("アカウント")
        } footer: {
            Text("削除すると、はじめてアプリを開いたときの画面に戻ります。")
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
            Text("一緒に使う方は、アプリの「この家計簿に参加する」から家計簿IDとパスワードを入力すると参加できます。安全のため、パスワードは家計簿IDとは別の方法でお伝えください。")
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
                        if category.isMonthly {
                            MonthlyBadge()
                        }
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
        LuxuryForm {
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
