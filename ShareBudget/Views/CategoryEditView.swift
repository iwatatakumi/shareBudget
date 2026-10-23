import SwiftData
import SwiftUI

// 項目の名前と目標金額を決める画面です。追加と編集の両方で使います。
struct CategoryEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// 編集する項目。nil のときは新しく追加します。
    let category: BudgetCategory?
    /// 新しく追加するときの並び順
    let nextSortOrder: Int

    @State private var name: String
    @State private var targetText: String
    @FocusState private var focused: Bool

    init(category: BudgetCategory?, nextSortOrder: Int = 0) {
        self.category = category
        self.nextSortOrder = nextSortOrder
        _name = State(initialValue: category?.name ?? "")
        let target = category?.monthlyTarget ?? 0
        _targetText = State(initialValue: target > 0 ? String(target) : "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }
    private var target: Int? { AmountInput.target(from: targetText) }
    private var canSave: Bool { !trimmedName.isEmpty && target != nil }

    var body: some View {
        Form {
            Section("項目の名前") {
                TextField("例: 食費", text: $name)
                    .focused($focused)
            }

            Section {
                HStack {
                    TextField("0", text: $targetText)
                        .keyboardType(.numberPad)
                        .focused($focused)
                        .font(.title2)
                    Text("円")
                }
            } header: {
                Text("1か月の目標金額")
            } footer: {
                Text("この金額より使わずに済んだ分が、旅行資金になります。")
            }
        }
        .navigationTitle(category == nil ? "項目の追加" : "項目の編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(!canSave)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { focused = false }
            }
        }
    }

    private func save() {
        guard let target else { return }

        if let category {
            category.name = trimmedName
            category.monthlyTarget = target
        } else {
            modelContext.insert(
                BudgetCategory(name: trimmedName, monthlyTarget: target, sortOrder: nextSortOrder)
            )
        }
        dismiss()
    }
}
