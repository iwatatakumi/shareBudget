import Foundation
import SwiftData

// 1つの項目について、今月いくら使ったかをまとめたものです。
struct CategorySummary: Identifiable {
    let category: BudgetCategory
    let spent: Int

    var id: PersistentIdentifier { category.persistentModelID }
    var name: String { category.name }
    var target: Int { category.monthlyTarget }
    /// 残り（マイナスなら目標オーバー）
    var remaining: Int { target - spent }
    var isOver: Bool { spent > target }
}

// 今月の家計簿の集計です。ホーム画面で使います。
struct MonthlySummary {
    let categories: [CategorySummary]
    /// 項目なしの支出の合計
    let uncategorizedSpent: Int

    /// - Parameters:
    ///   - categories: 項目（表示したい順に並べたもの）
    ///   - expenses: 今月の支出だけ
    init(categories: [BudgetCategory], expenses: [Expense]) {
        var spentByCategory: [PersistentIdentifier: Int] = [:]
        var uncategorized = 0
        for expense in expenses {
            if let category = expense.category {
                spentByCategory[category.persistentModelID, default: 0] += expense.amount
            } else {
                uncategorized += expense.amount
            }
        }

        self.categories = categories.map { category in
            CategorySummary(
                category: category,
                spent: spentByCategory[category.persistentModelID] ?? 0
            )
        }
        self.uncategorizedSpent = uncategorized
    }

    var totalTarget: Int {
        categories.reduce(0) { $0 + $1.target }
    }

    var totalSpent: Int {
        categories.reduce(uncategorizedSpent) { $0 + $1.spent }
    }

    /// 今月の残り（マイナスなら目標オーバー）
    var totalRemaining: Int {
        totalTarget - totalSpent
    }

    /// このままいけば今月貯まる旅行資金。
    /// 各項目の「目標 − 使った額」の合計で、マイナスの月は0円にします。
    var projectedTravelFund: Int {
        max(0, totalRemaining)
    }
}
