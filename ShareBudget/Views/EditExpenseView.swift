import SwiftData
import SwiftUI

// 保存した支出を修正・削除する画面です。一覧の行を押すと開きます。
struct EditExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let expense: Expense

    @State private var amountText: String
    @State private var category: BudgetCategory?
    @State private var date: Date
    @State private var memo: String
    @State private var showDeleteConfirm = false
    @FocusState private var amountFocused: Bool

    init(expense: Expense) {
        self.expense = expense
        // 画面を開いたときに、今の内容を入力欄に入れておきます。
        _amountText = State(initialValue: String(expense.amount))
        _category = State(initialValue: expense.category)
        _date = State(initialValue: expense.date)
        _memo = State(initialValue: expense.memo)
    }

    private var amount: Int? { ExpenseInput.amount(from: amountText) }
    private var canSave: Bool { amount != nil && category != nil }

    var body: some View {
        Form {
            ExpenseFormFields(
                amountText: $amountText,
                category: $category,
                date: $date,
                memo: $memo,
                amountFocused: $amountFocused
            )

            Section {
                Button("この支出を削除", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationTitle("支出の修正")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(!canSave)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { amountFocused = false }
            }
        }
        .confirmationDialog(
            "この支出を削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                modelContext.delete(expense)
                dismiss()
            }
        }
    }

    private func save() {
        guard let amount, let category else { return }
        expense.amount = amount
        expense.category = category
        expense.date = date
        expense.memo = memo.trimmingCharacters(in: .whitespaces)
        dismiss()
    }
}
