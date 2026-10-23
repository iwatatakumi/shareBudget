import SwiftData
import SwiftUI

// 項目と目標金額を設定する画面です。
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]

    // 削除してよいか確認中の項目
    @State private var categoryToDelete: BudgetCategory?

    private var totalTarget: Int {
        categories.reduce(0) { $0 + $1.monthlyTarget }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories) { category in
                        NavigationLink {
                            CategoryEditView(category: category)
                        } label: {
                            HStack {
                                Text(category.name)
                                Spacer()
                                Text(category.monthlyTarget.yenText)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        categoryToDelete = offsets.first.map { categories[$0] }
                    }
                    .onMove(perform: move)

                    NavigationLink {
                        CategoryEditView(category: nil, nextSortOrder: (categories.last?.sortOrder ?? -1) + 1)
                    } label: {
                        Label("項目を追加", systemImage: "plus")
                    }
                } header: {
                    Text("項目と1か月の目標金額")
                } footer: {
                    Text("目標の合計: \(totalTarget.yenText)。右上の「編集」で並び替えができます。")
                }

                Section("ルームメイト") {
                    Text("2人で共有する機能は、このあとのステップで追加します。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
            .toolbar {
                EditButton()
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
                    modelContext.delete(category)
                    categoryToDelete = nil
                }
            } message: { _ in
                Text("この項目で入力した支出は消えずに「項目なし」になります。")
            }
        }
    }

    // 並び替えた順番を保存します。
    private func move(from source: IndexSet, to destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in reordered.enumerated() {
            category.sortOrder = index
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(PreviewData.container)
}
