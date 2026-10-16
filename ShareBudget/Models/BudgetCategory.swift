import Foundation
import SwiftData

// 「食費」「日用品」などの項目です。
// @Model を付けると、SwiftData（iPhoneの中にデータを保存する仕組み）で保存できるようになります。
@Model
final class BudgetCategory {
    /// 項目の名前（例: 食費）
    var name: String
    /// 1か月の目標金額（円）。ステップ4で設定できるようにします。
    var monthlyTarget: Int
    /// 並び順。小さい数字ほど上に表示します。
    var sortOrder: Int

    /// この項目に入っている支出の一覧。
    /// 項目を消しても支出は残し、項目なしの状態にします（.nullify）。
    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense] = []

    init(name: String, monthlyTarget: Int = 0, sortOrder: Int) {
        self.name = name
        self.monthlyTarget = monthlyTarget
        self.sortOrder = sortOrder
    }
}

extension BudgetCategory {
    /// 初めてアプリを開いたときに用意しておく項目です。
    static let defaultNames = ["食費", "日用品", "光熱費", "交際費", "その他"]

    /// 項目がまだ1つもなければ、最初の項目を保存します。
    static func insertDefaultsIfNeeded(into context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<BudgetCategory>())) ?? 0
        guard count == 0 else { return }

        for (index, name) in defaultNames.enumerated() {
            context.insert(BudgetCategory(name: name, sortOrder: index))
        }
    }
}
