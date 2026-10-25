import SwiftUI

// 今月の支出を新しい順に並べる画面です。
struct ExpenseListView: View {
    @Environment(BudgetStore.self) private var store

    private var total: Int {
        store.expenses.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            LuxuryList {
                if store.expenses.isEmpty {
                    ContentUnavailableView(
                        "今月の支出はまだありません",
                        systemImage: "list.bullet",
                        description: Text("「入力」タブから支出を追加できます。")
                    )
                } else {
                    Section {
                        HStack {
                            Text("今月の合計")
                            Spacer()
                            Text(total.yenText)
                                .bold()
                        }
                    }

                    Section("今月の支出") {
                        ForEach(store.expenses) { expense in
                            NavigationLink {
                                EditExpenseScreen(expense: expense)
                            } label: {
                                ExpenseRow(expense: expense)
                            }
                        }
                        // 行を左にスワイプすると削除できます。
                        .onDelete { offsets in
                            let targets = offsets.map { store.expenses[$0] }
                            Task {
                                for expense in targets {
                                    await store.deleteExpense(expense)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("支出の一覧")
            // 下に引っぱると、ルームメイトが入力した支出も読み込み直します。
            .refreshable {
                await store.reload()
            }
        }
    }
}

// 支出を修正する画面です。
private struct EditExpenseScreen: View {
    @Environment(\.dismiss) private var dismiss
    let expense: Expense

    var body: some View {
        ExpenseForm(expense: expense) {
            dismiss()
        }
        .navigationTitle("支出の修正")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// 一覧の1行ぶんの見た目です。
struct ExpenseRow: View {
    @Environment(BudgetStore.self) private var store
    let expense: Expense

    /// 例: 「たくみ 600円・ルームメイト 600円」
    private var shareText: String {
        store.members
            .compactMap { member -> String? in
                let amount = expense.share(of: member.userId)
                return amount > 0 ? "\(member.displayName) \(amount.yenText)" : nil
            }
            .joined(separator: "・")
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryBadge(
                name: store.categoryName(expense.categoryId),
                color: store.categoryColor(expense.categoryId)
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(store.categoryName(expense.categoryId))
                    .font(.headline)
                Text(expense.date.formatted(.dateTime.month().day().weekday()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !expense.memo.isEmpty {
                    Text(expense.memo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if store.members.count > 1 {
                    Text(shareText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(expense.amount.yenText)
        }
    }
}

#Preview {
    ExpenseListView()
        .environment(PreviewData.store)
}
