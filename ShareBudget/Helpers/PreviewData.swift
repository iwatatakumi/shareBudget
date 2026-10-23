import Foundation

// Xcodeのプレビュー（右側に出る画面の見本）で使う、お試し用のデータです。
// Supabaseにはつながず、本物のデータにも影響しません。
@MainActor
enum PreviewData {
    static let store: BudgetStore = {
        let me = UUID()
        let roommate = UUID()
        let householdId = UUID()
        let store = BudgetStore(previewUserId: me)

        store.household = Household(id: householdId, name: "家計簿", inviteCode: "AB12CD")
        store.members = [
            Member(householdId: householdId, userId: me, displayName: "たくみ"),
            Member(householdId: householdId, userId: roommate, displayName: "ルームメイト"),
        ]
        let food = BudgetCategory(id: UUID(), householdId: householdId, name: "食費", sortOrder: 0)
        let daily = BudgetCategory(id: UUID(), householdId: householdId, name: "日用品", sortOrder: 1)
        store.categories = [food, daily]
        store.targets = [
            MemberTarget(categoryId: food.id, userId: me, householdId: householdId, amount: 15000),
            MemberTarget(categoryId: food.id, userId: roommate, householdId: householdId, amount: 15000),
            MemberTarget(categoryId: daily.id, userId: me, householdId: householdId, amount: 4000),
            MemberTarget(categoryId: daily.id, userId: roommate, householdId: householdId, amount: 4000),
        ]
        let today = DayString.string(from: Date())
        store.expenses = [
            Expense(
                id: UUID(), householdId: householdId, categoryId: food.id, amount: 1200,
                spentOn: today, memo: "スーパー", createdBy: me,
                shares: [ExpenseShare(userId: me, amount: 600), ExpenseShare(userId: roommate, amount: 600)]
            ),
            Expense(
                id: UUID(), householdId: householdId, categoryId: daily.id, amount: 580,
                spentOn: today, memo: "", createdBy: roommate,
                shares: [ExpenseShare(userId: roommate, amount: 580)]
            ),
        ]
        return store
    }()
}
