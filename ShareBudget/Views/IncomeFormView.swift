import SwiftUI

// 臨時収入を入力する画面です。保存すると、その金額が旅行資金に足されます。
struct IncomeFormView: View {
    @Environment(BudgetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var date = Date()
    @State private var memo = ""
    @State private var isSaving = false
    @FocusState private var focused: Bool

    private var amount: Int? {
        AmountInput.amount(from: amountText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("金額") {
                    HStack {
                        TextField("例: 10000", text: $amountText)
                            .keyboardType(.numberPad)
                            .focused($focused)
                        Text("円")
                    }
                }
                Section {
                    // 未来の日付は月ごとの記録に入らないので、今日までにしています。
                    DatePicker("受け取った日", selection: $date, in: ...Date(), displayedComponents: .date)
                    TextField("メモ（例: ボーナス、お祝い）", text: $memo)
                        .focused($focused)
                }
            }
            .navigationTitle("臨時収入の追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .disabled(amount == nil || isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { focused = false }
                }
            }
        }
    }

    private func save() async {
        guard let amount else { return }
        isSaving = true
        defer { isSaving = false }
        let trimmedMemo = memo.trimmingCharacters(in: .whitespaces)
        if await store.addIncome(amount: amount, date: date, memo: trimmedMemo) {
            dismiss()
        }
    }
}

#Preview {
    IncomeFormView()
        .environment(PreviewData.store)
}
