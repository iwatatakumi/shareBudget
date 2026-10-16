import SwiftData
import SwiftUI

// 支出を新しく入力する画面です。
struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext

    // @State は「この画面が覚えておく値」です。入力中の内容をここに入れます。
    @State private var amountText = ""
    @State private var category: BudgetCategory?
    @State private var date = Date()
    @State private var memo = ""
    @State private var showSavedMessage = false
    @FocusState private var amountFocused: Bool

    private var amount: Int? { ExpenseInput.amount(from: amountText) }
    private var canSave: Bool { amount != nil && category != nil }

    var body: some View {
        NavigationStack {
            Form {
                ExpenseFormFields(
                    amountText: $amountText,
                    category: $category,
                    date: $date,
                    memo: $memo,
                    amountFocused: $amountFocused
                )

                Section {
                    Button("保存する") { save() }
                        .frame(maxWidth: .infinity)
                        .disabled(!canSave)
                } footer: {
                    if !canSave {
                        Text("金額と項目を入れると保存できます。")
                    }
                }
            }
            .navigationTitle("支出の入力")
            .toolbar {
                // 数字キーボードには「閉じる」ボタンがないので、キーボードの上に「完了」を出します。
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { amountFocused = false }
                }
            }
            .alert("保存しました", isPresented: $showSavedMessage) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func save() {
        guard let amount, let category else { return }

        let expense = Expense(
            amount: amount,
            date: date,
            memo: memo.trimmingCharacters(in: .whitespaces),
            category: category
        )
        modelContext.insert(expense)

        // 次の入力のために欄を空に戻します（項目はそのまま残します）。
        amountText = ""
        memo = ""
        date = Date()
        amountFocused = false
        showSavedMessage = true
    }
}

#Preview {
    AddExpenseView()
        .modelContainer(PreviewData.container)
}
