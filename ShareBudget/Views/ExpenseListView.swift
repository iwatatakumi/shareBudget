import SwiftData
import SwiftUI

// 今月の支出を新しい順に並べる画面です。
struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext

    // @Query は保存されている支出を取り出し、変わったら画面を自動で更新してくれます。
    @Query(sort: [
        SortDescriptor(\Expense.date, order: .reverse),
        SortDescriptor(\Expense.createdAt, order: .reverse),
    ])
    private var allExpenses: [Expense]

    private var expenses: [Expense] {
        allExpenses.filter { $0.date.isInCurrentMonth }
    }

    private var total: Int {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                if expenses.isEmpty {
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
                        ForEach(expenses) { expense in
                            NavigationLink {
                                EditExpenseView(expense: expense)
                            } label: {
                                ExpenseRow(expense: expense)
                            }
                        }
                        // 行を左にスワイプすると削除できます。
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("支出の一覧")
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(expenses[index])
        }
        modelContext.saveChanges()
    }
}

// 一覧の1行ぶんの見た目です。
struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.category?.name ?? "項目なし")
                    .font(.headline)
                Text(expense.date.formatted(.dateTime.month().day().weekday()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !expense.memo.isEmpty {
                    Text(expense.memo)
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
        .modelContainer(PreviewData.container)
}
