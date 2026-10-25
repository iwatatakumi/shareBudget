import SwiftUI

// 項目の名前と、人ごとの目標金額を決める画面です。追加と編集の両方で使います。
struct CategoryEditView: View {
    @Environment(BudgetStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// 編集する項目。nil のときは新しく追加します。
    let category: BudgetCategory?

    @State private var name: String
    /// 人ごとの目標金額の入力欄
    @State private var targetTexts: [UUID: String] = [:]
    @State private var didLoad = false
    @State private var isSaving = false
    @FocusState private var focused: Bool

    init(category: BudgetCategory?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    /// 人ごとの目標金額。正しくない入力があれば nil
    private var targets: [UUID: Int]? {
        var result: [UUID: Int] = [:]
        for member in store.members {
            guard let value = AmountInput.target(from: targetTexts[member.userId] ?? "") else { return nil }
            result[member.userId] = value
        }
        return result
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && targets != nil && !isSaving
    }

    var body: some View {
        LuxuryForm {
            Section("項目の名前") {
                TextField("例: 食費", text: $name)
                    .focused($focused)
            }

            Section {
                ForEach(store.members) { member in
                    HStack {
                        Text(member.displayName)
                        Spacer()
                        TextField("0", text: targetBinding(for: member.userId))
                            .keyboardType(.numberPad)
                            .focused($focused)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                        Text("円")
                    }
                }
                HStack {
                    Text("合計")
                    Spacer()
                    Text(((targets ?? [:]).values.reduce(0, +)).yenText)
                        .bold()
                }
            } header: {
                Text("1か月の目標金額（人ごと）")
            } footer: {
                let total = (targets ?? [:]).values.reduce(0, +)
                let daily = DailyBudget()
                Text("1日あたり \(daily.perDay(total).yenText)（合計 ÷ 今月の\(daily.daysInMonth)日）。この金額より使わずに済んだ分が、旅行資金になります。")
            }
        }
        .navigationTitle(category == nil ? "項目の追加" : "項目の編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    Task { await save() }
                }
                .disabled(!canSave)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { focused = false }
            }
        }
        .onAppear(perform: loadTargets)
    }

    private func targetBinding(for userId: UUID) -> Binding<String> {
        Binding(
            get: { targetTexts[userId] ?? "" },
            set: { targetTexts[userId] = $0 }
        )
    }

    // 画面を開いたときに、いまの目標金額を入力欄に入れます。
    private func loadTargets() {
        guard !didLoad else { return }
        didLoad = true
        guard let category else { return }
        for member in store.members {
            let amount = store.target(categoryId: category.id, userId: member.userId)
            targetTexts[member.userId] = amount > 0 ? String(amount) : ""
        }
    }

    private func save() async {
        guard let targets else { return }
        isSaving = true
        defer { isSaving = false }
        if await store.saveCategory(category, name: trimmedName, targetsByUser: targets) {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        CategoryEditView(category: PreviewData.store.categories.first)
    }
    .environment(PreviewData.store)
}
