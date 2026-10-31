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
    /// 月に1回まとめて払う項目（家賃・光熱費など）か
    var isMonthly: Bool { category.isMonthly }
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
    /// 今日の支出の合計（月払いの項目は含めません）
    let todaySpent: Int
    /// 今月の臨時収入の合計
    let extraIncome: Int
    let daily: DailyBudget

    @MainActor
    init(store: BudgetStore, now: Date = Date()) {
        let expenses = store.expenses
        daily = DailyBudget(now: now)
        let todayString = DayString.string(from: now)
        extraIncome = store.incomeTotal(month: String(todayString.prefix(7)))
        // 家賃など月払いの項目は、払った日だけ大きくなるので「今日の支出」に含めません
        let monthlyIds = Set(store.categories.filter(\.isMonthly).map(\.id))
        todaySpent = expenses
            .filter { expense in
                guard expense.spentOn == todayString else { return false }
                guard let categoryId = expense.categoryId else { return true }
                return !monthlyIds.contains(categoryId)
            }
            .reduce(0) { $0 + $1.amount }

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

    /// 日割りする項目（月払いでない項目）の目標の合計
    var dailyCategoriesTarget: Int {
        categories.filter { !$0.isMonthly }.reduce(0) { $0 + $1.target }
    }

    /// 1日あたりの目標（月払いでない項目の合計を日割り）
    var dailyTarget: Int {
        daily.perDay(dailyCategoriesTarget)
    }

    /// 今日までに使ってよい金額。
    /// ・ふつうの項目は、月の目標を今日までの日数で日割りした額。
    /// ・月払いの項目は、払った額と同じ（目標以内なら差は0）。目標を超えたときだけ、超えた分がマイナスになります。
    ///   月払いの項目の残りは、月が終わってから旅行資金に入ります。
    var targetUntilToday: Int {
        categories.reduce(0) { total, item in
            total + (item.isMonthly ? min(item.spent, item.target) : daily.untilToday(item.target))
        }
    }

    /// 今月の残り（マイナスなら目標オーバー）
    var totalRemaining: Int {
        totalTarget - totalSpent
    }

    /// 今日までの旅行資金。
    /// 各項目の「今日までの目標 − 使った額」の合計から、項目なしの支出を引き、今月の臨時収入を足した額です。
    /// 目標より多く使っているとマイナスになります。
    var projectedTravelFund: Int {
        targetUntilToday - totalSpent + extraIncome
    }
}
