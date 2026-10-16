import Foundation
import SwiftData

// 1回ぶんの支出です。
@Model
final class Expense {
    /// 金額（円）
    var amount: Int
    /// 使った日
    var date: Date
    /// メモ（空でもよい）
    var memo: String
    /// どの項目の支出か
    var category: BudgetCategory?
    /// 入力した日時（同じ日の支出を並べる順番に使います）
    var createdAt: Date

    init(amount: Int, date: Date, memo: String, category: BudgetCategory?) {
        self.amount = amount
        self.date = date
        self.memo = memo
        self.category = category
        self.createdAt = Date()
    }
}
