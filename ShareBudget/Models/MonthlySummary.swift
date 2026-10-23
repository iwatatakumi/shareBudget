import Foundation

// 今月の家計簿の集計です。ホーム画面で使います。
// 「目標」はメンバー全員の目標金額の合計、「使った額」は支出の合計です。
// 人ごとの「使った額」は、支出のうちその人が負担する分（配分）の合計です。

/// 1人ぶんの、今月の目標と使った額
struct MemberSummary: Identifiable {
    let member: Member
    let target: Int
    let spent: Int

    var id: UUID { member.userId }
    var name: String { member.displayName }
    /// 目標からの差分（マイナスなら目標オーバー）
    var difference: Int { target - spent }
}

/// 1つの項目の、今月の目標と使った額
struct CategorySummary: Identifiable {
    let category: BudgetCategory
    let target: Int
    let spent: Int
    /// その項目の、人ごとの目標と使った額
    let members: [MemberSummary]

    var id: UUID { category.id }
    var name: String { category.name }
    /// 残り（マイナスなら目標オーバー）
    var remaining: Int { target - spent }
    var isOver: Bool { spent > target }
}

struct MonthlySummary {
    let categories: [CategorySummary]
    let members: [MemberSummary]
    /// 項目なしの支出の合計
    let uncategorizedSpent: Int

    @MainActor
    init(store: BudgetStore) {
        let expenses = store.expenses

        categories = store.categories.map { category in
            let inCategory = expenses.filter { $0.categoryId == category.id }
            let memberSummaries = store.members.map { member in
                MemberSummary(
                    member: member,
                    target: store.target(categoryId: category.id, userId: member.userId),
                    spent: inCategory.reduce(0) { $0 + $1.share(of: member.userId) }
                )
            }
            return CategorySummary(
                category: category,
                target: memberSummaries.reduce(0) { $0 + $1.target },
                spent: inCategory.reduce(0) { $0 + $1.amount },
                members: memberSummaries
            )
        }

        let categoryIds = Set(store.categories.map(\.id))
        uncategorizedSpent = expenses
            .filter { expense in expense.categoryId.map { !categoryIds.contains($0) } ?? true }
            .reduce(0) { $0 + $1.amount }

        members = store.members.map { member in
            MemberSummary(
                member: member,
                target: store.categories.reduce(0) { $0 + store.target(categoryId: $1.id, userId: member.userId) },
                spent: expenses.reduce(0) { $0 + $1.share(of: member.userId) }
            )
        }
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
    /// 各項目の「目標 − 使った額」の合計で、目標を超えた月はマイナスになります。
    var projectedTravelFund: Int {
        totalRemaining
    }
}
