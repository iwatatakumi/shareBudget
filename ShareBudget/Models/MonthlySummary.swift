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

/// 月の目標金額を、その月の日数で日割りする計算です。
/// 1円未満は切り捨てます（例: 30,000円 ÷ 31日 = 967円）。
struct DailyBudget {
    /// 今月の日数（28〜31）
    let daysInMonth: Int
    /// 今日が今月の何日目か（1〜31）
    let today: Int

    init(now: Date = Date(), calendar: Calendar = .current) {
        daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        today = calendar.component(.day, from: now)
    }

    /// 1日あたりの目標金額
    func perDay(_ monthlyTarget: Int) -> Int {
        monthlyTarget / daysInMonth
    }

    /// 今日までに使ってよい金額（月の目標 × 今日までの日数 ÷ 月の日数）
    func untilToday(_ monthlyTarget: Int) -> Int {
        monthlyTarget * today / daysInMonth
    }
}

struct MonthlySummary {
    let categories: [CategorySummary]
    let members: [MemberSummary]
    /// 項目なしの支出の合計
    let uncategorizedSpent: Int
    /// 今日の支出の合計
    let todaySpent: Int
    let daily: DailyBudget

    @MainActor
    init(store: BudgetStore, now: Date = Date()) {
        let expenses = store.expenses
        daily = DailyBudget(now: now)
        let todayString = DayString.string(from: now)
        todaySpent = expenses.filter { $0.spentOn == todayString }.reduce(0) { $0 + $1.amount }

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

    /// 1日あたりの目標（全項目の合計を日割り）
    var dailyTarget: Int {
        daily.perDay(totalTarget)
    }

    /// 今日までに使ってよい金額
    var targetUntilToday: Int {
        daily.untilToday(totalTarget)
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
