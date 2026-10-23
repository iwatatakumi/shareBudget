import SwiftData
import SwiftUI

// 支出の「金額・項目・日付・メモ」の入力欄です。
// 新しく入力する画面と、修正する画面の両方で使います。
struct ExpenseFormFields: View {
    @Binding var amountText: String
    @Binding var category: BudgetCategory?
    @Binding var date: Date
    @Binding var memo: String
    var amountFocused: FocusState<Bool>.Binding

    // 保存されている項目を、並び順どおりに取り出します。
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]

    var body: some View {
        Section("金額") {
            HStack {
                TextField("0", text: $amountText)
                    .keyboardType(.numberPad)
                    .focused(amountFocused)
                    .font(.title2)
                Text("円")
            }
        }

        Section("内容") {
            Picker("項目", selection: $category) {
                Text("選んでください").tag(BudgetCategory?.none)
                ForEach(categories) { item in
                    Text(item.name).tag(BudgetCategory?.some(item))
                }
            }
            DatePicker("日付", selection: $date, displayedComponents: .date)
            TextField("メモ（なくてもOK）", text: $memo)
        }
    }
}
