import SwiftUI

// 支出の入力欄です。新しく入力する画面と、修正する画面の両方で使います。
struct ExpenseForm: View {
    @Environment(BudgetStore.self) private var store

    /// 修正する支出。nil のときは新しく追加します。
    let expense: Expense?
    /// 保存や削除が終わったときに呼ばれます。
    let onFinished: () -> Void

    @State private var amountText: String
    @State private var categoryId: UUID?
    @State private var date: Date
    @State private var memo: String
    @State private var splitMode: SplitMode
    /// 「金額を指定」のときの、人ごとの入力欄
    @State private var customTexts: [UUID: String]
    @State private var isSaving = false
    @State private var showDeleteConfirm = false
    @FocusState private var focused: Bool

    init(expense: Expense?, defaultCategoryId: UUID? = nil, onFinished: @escaping () -> Void) {
        self.expense = expense
        self.onFinished = onFinished
        _amountText = State(initialValue: expense.map { String($0.amount) } ?? "")
        _categoryId = State(initialValue: expense?.categoryId ?? defaultCategoryId)
        _date = State(initialValue: expense?.date ?? Date())
        _memo = State(initialValue: expense?.memo ?? "")

        // 修正のときは、保存されている配分をそのまま入力欄に入れます。
        if let expense {
            _splitMode = State(initialValue: .custom)
            var texts: [UUID: String] = [:]
            for share in expense.shares {
                texts[share.userId] = String(share.amount)
            }
            _customTexts = State(initialValue: texts)
        } else {
            _splitMode = State(initialValue: .equal)
            _customTexts = State(initialValue: [:])
        }
    }

    private var amount: Int? { AmountInput.amount(from: amountText) }

    private var customAmounts: [UUID: Int] {
        customTexts.compactMapValues { AmountInput.target(from: $0) }
    }

    /// いまの入力内容での配分。うまく分けられないときは nil
    private var shares: [UUID: Int]? {
        guard let amount, let me = store.userId else { return nil }
        return ShareSplit.shares(
            amount: amount,
            mode: store.members.count > 1 ? splitMode : .onlyMe,
            memberIds: store.members.map(\.userId),
            me: me,
            customAmounts: customAmounts
        )
    }

    private var canSave: Bool {
        amount != nil && categoryId != nil && shares != nil && !isSaving
    }

    var body: some View {
        Form {
            Section("金額") {
                HStack {
                    TextField("0", text: $amountText)
                        .keyboardType(.numberPad)
                        .focused($focused)
                        .font(.title2)
                    Text("円")
                }
            }

            Section("内容") {
                Picker("項目", selection: $categoryId) {
                    Text("選んでください").tag(UUID?.none)
                    ForEach(store.categories) { category in
                        Text(category.name).tag(UUID?.some(category.id))
                    }
                }
                DatePicker("日付", selection: $date, displayedComponents: .date)
                TextField("メモ（なくてもOK）", text: $memo)
            }

            if store.members.count > 1 {
                splitSection
            }

            Section {
                Button(expense == nil ? "保存する" : "修正を保存する") {
                    Task { await save() }
                }
                .frame(maxWidth: .infinity)
                .disabled(!canSave)
            } footer: {
                if amount == nil || categoryId == nil {
                    Text("金額と項目を入れると保存できます。")
                } else if shares == nil {
                    Text("配分の合計を金額と同じにしてください。")
                }
            }

            if expense != nil {
                Section {
                    Button("この支出を削除", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
        }
        .toolbar {
            // 数字キーボードには「閉じる」ボタンがないので、キーボードの上に「完了」を出します。
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { focused = false }
            }
        }
        .confirmationDialog(
            "この支出を削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除する", role: .destructive) {
                Task {
                    if let expense {
                        await store.deleteExpense(expense)
                    }
                    onFinished()
                }
            }
        }
        .disabled(isSaving)
    }

    // 「誰がいくら負担するか」の入力欄
    private var splitSection: some View {
        Section {
            Picker("配分", selection: $splitMode) {
                ForEach(SplitMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            ForEach(store.members) { member in
                HStack {
                    Text(member.displayName)
                    Spacer()
                    if splitMode == .custom {
                        TextField("0", text: customBinding(for: member.userId))
                            .keyboardType(.numberPad)
                            .focused($focused)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                        Text("円")
                    } else {
                        Text((shares?[member.userId] ?? 0).yenText)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("配分（誰がいくら負担するか）")
        } footer: {
            if splitMode == .custom, let amount {
                let rest = amount - customAmounts.values.reduce(0, +)
                if rest != 0 {
                    Text(rest > 0 ? "あと\(rest.yenText)を割り当ててください。" : "\((-rest).yenText)多く割り当てています。")
                }
            } else if splitMode == .equal {
                Text("割り切れない端数は自分の負担になります。")
            }
        }
    }

    private func customBinding(for userId: UUID) -> Binding<String> {
        Binding(
            get: { customTexts[userId] ?? "" },
            set: { customTexts[userId] = $0 }
        )
    }

    private func save() async {
        guard let amount, let shares else { return }
        isSaving = true
        defer { isSaving = false }

        let saved = await store.saveExpense(
            id: expense?.id,
            categoryId: categoryId,
            amount: amount,
            date: date,
            memo: memo.trimmingCharacters(in: .whitespaces),
            shares: shares
        )
        if saved {
            focused = false
            onFinished()
        }
    }
}

#Preview {
    NavigationStack {
        ExpenseForm(expense: nil) {}
    }
    .environment(PreviewData.store)
}
