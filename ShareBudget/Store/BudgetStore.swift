import Foundation
import Observation
import Supabase

// アプリ全体のデータをまとめて持ち、Supabaseとのやり取りをする係です。
// 画面はこの BudgetStore からデータを読み、変更もこの BudgetStore にお願いします。
@MainActor
@Observable
final class BudgetStore {
    /// いまアプリがどの状態か
    enum Phase {
        /// Supabaseの設定がまだ（SupabaseConfig.swift を書きかえていない）
        case notConfigured
        case loading
        /// Supabaseにつながらなかった（ネットがない、匿名ログインがオフ など）
        case connectionFailed
        /// まだ家計簿に参加していない
        case needsHousehold
        /// 家計簿を使える
        case ready
    }

    var phase: Phase = .loading
    var userId: UUID?
    var household: Household?
    var members: [Member] = []
    var categories: [BudgetCategory] = []
    var targets: [MemberTarget] = []
    /// 今月の支出（新しい順）
    var expenses: [Expense] = []
    /// 月ごとの支出の合計（"2026-10" → 金額）。旅行資金の記録に使います。
    var monthlySpent: [String: Int] = [:]
    /// 画面に出すエラーの文章
    var errorMessage: String?
    /// つながらなかったときの、くわしいエラーの文章（つながらなかった画面に出します）
    var connectionError: String?

    private let client: SupabaseClient?

    init() {
        if SupabaseConfig.isConfigured, let url = URL(string: SupabaseConfig.url) {
            client = SupabaseClient(supabaseURL: url, supabaseKey: SupabaseConfig.publishableKey)
        } else {
            client = nil
            phase = .notConfigured
        }
    }

    /// プレビュー用（Supabaseにつながない）
    init(previewUserId: UUID) {
        client = nil
        userId = previewUserId
        phase = .ready
    }

    // MARK: - 起動

    /// アプリを開いたときに、Supabaseにつないでデータを読み込みます。
    /// メールアドレスは使わず「匿名ログイン」をします。これはSupabaseが、この端末のアプリ専用の
    /// 名前のない利用者を自動で作ってくれる仕組みで、一度作ると端末に記録され、次からも同じ利用者になります。
    func start() async {
        guard let client else { return }
        phase = .loading
        connectionError = nil
        do {
            var session = try? await client.auth.session
            if session != nil {
                // 端末に残っているログイン情報が、いまのSupabaseで使えるか確かめます。
                // データベースを作り直すと古いログイン情報は使えなくなるので、そのときは消して作り直します。
                do {
                    _ = try await client.auth.user()
                } catch let error as URLError {
                    // インターネットにつながらないだけなので、ログイン情報は消さない
                    throw error
                } catch {
                    try? await client.auth.signOut(scope: .local)
                    session = nil
                }
            }
            if session == nil {
                session = try await client.auth.signInAnonymously()
            }
            userId = session?.user.id
            await reload()
        } catch {
            connectionError = error.localizedDescription
            phase = .connectionFailed
        }
    }

    // MARK: - 家計簿を作る・参加する

    /// 新しい家計簿を作ります。作った人が管理者になり、password が参加用パスワードになります。
    func createHousehold(displayName: String, password: String) async {
        guard let client else { return }
        await run {
            try await client
                .rpc("create_household", params: ["p_display_name": displayName, "p_password": password])
                .execute()
            await self.reload()
        }
    }

    /// 家計簿ID（招待コード）と、管理者から教えてもらったパスワードで参加します。
    func joinHousehold(inviteCode: String, password: String, displayName: String) async {
        guard let client else { return }
        await run {
            try await client
                .rpc("join_household", params: [
                    "p_invite_code": inviteCode,
                    "p_password": password,
                    "p_display_name": displayName,
                ])
                .execute()
            await self.reload()
        }
    }

    /// 管理者が参加用パスワードを変えます。
    func changePassword(_ password: String) async -> Bool {
        guard let client else { return false }
        return await run {
            try await client
                .rpc("change_household_password", params: ["p_password": password])
                .execute()
            await self.reload()
        }
    }

    // MARK: - 読み込み

    /// Supabaseから最新のデータを読み込みます。
    func reload() async {
        guard let client, let userId else { return }
        do {
            // 自分の家計簿のメンバー（権限の設定で、自分の家計簿の分しか返ってきません）
            let members: [Member] = try await client.from("members").select().execute().value
            guard members.contains(where: { $0.userId == userId }) else {
                clearData()
                phase = .needsHousehold
                return
            }

            let households: [Household] = try await client.from("households").select().execute().value
            let categories: [BudgetCategory] = try await client
                .from("categories").select()
                .order("sort_order")
                .execute().value
            let targets: [MemberTarget] = try await client.from("member_targets").select().execute().value

            let month = DayString.currentMonthRange()
            let expenses: [Expense] = try await client
                .from("expenses").select("*, expense_shares(user_id, amount)")
                .gte("spent_on", value: month.start)
                .lt("spent_on", value: month.end)
                .order("spent_on", ascending: false)
                .order("created_at", ascending: false)
                .execute().value

            let monthly: [MonthlySpent] = try await client.rpc("monthly_spent").execute().value

            self.monthlySpent = Dictionary(monthly.map { ($0.month, $0.total) }, uniquingKeysWith: +)
            self.household = households.first
            self.members = members.sorted { $0.userId == userId && $1.userId != userId }
            self.categories = categories
            self.targets = targets
            self.expenses = expenses
            phase = .ready
        } catch {
            if phase == .loading {
                connectionError = error.localizedDescription
                phase = .connectionFailed
            } else {
                errorMessage = "データを読み込めませんでした。\n\(error.localizedDescription)"
            }
        }
    }

    // MARK: - 支出

    /// 支出を保存します。id が nil なら新しく追加、あれば修正します。
    /// shares は「誰がいくら負担するか」で、合計が amount と同じである必要があります。
    func saveExpense(
        id: UUID?,
        categoryId: UUID?,
        amount: Int,
        date: Date,
        memo: String,
        shares: [UUID: Int]
    ) async -> Bool {
        guard let client else { return false }
        let params = SaveExpenseParams(
            id: id,
            categoryId: categoryId,
            amount: amount,
            spentOn: DayString.string(from: date),
            memo: memo,
            shares: shares.map { SaveExpenseParams.Share(userId: $0.key, amount: $0.value) }
        )
        return await run {
            try await client.rpc("save_expense", params: params).execute()
            await self.reload()
        }
    }

    func deleteExpense(_ expense: Expense) async {
        guard let client else { return }
        await run {
            try await client.from("expenses").delete().eq("id", value: expense.id.uuidString).execute()
            await self.reload()
        }
    }

    // MARK: - 項目と目標金額

    /// 項目を保存します。category が nil なら新しく追加します。
    /// targetsByUser は「人ごとの1か月の目標金額」です。
    func saveCategory(_ category: BudgetCategory?, name: String, targetsByUser: [UUID: Int]) async -> Bool {
        guard let client, let household else { return false }
        return await run {
            let categoryId: UUID
            if let category {
                try await client
                    .from("categories")
                    .update(["name": name])
                    .eq("id", value: category.id.uuidString)
                    .execute()
                categoryId = category.id
            } else {
                let nextOrder = (self.categories.map(\.sortOrder).max() ?? -1) + 1
                let created: BudgetCategory = try await client
                    .from("categories")
                    .insert(NewCategory(householdId: household.id, name: name, sortOrder: nextOrder))
                    .select()
                    .single()
                    .execute()
                    .value
                categoryId = created.id
            }

            let rows = targetsByUser.map { userId, amount in
                MemberTarget(categoryId: categoryId, userId: userId, householdId: household.id, amount: amount)
            }
            if !rows.isEmpty {
                try await client
                    .from("member_targets")
                    .upsert(rows, onConflict: "category_id,user_id")
                    .execute()
            }
            await self.reload()
        }
    }

    func deleteCategory(_ category: BudgetCategory) async {
        guard let client else { return }
        await run {
            try await client.from("categories").delete().eq("id", value: category.id.uuidString).execute()
            await self.reload()
        }
    }

    /// 項目の並び順を保存します。
    func moveCategories(from source: IndexSet, to destination: Int) async {
        guard let client else { return }
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        categories = reordered
        await run {
            for (index, category) in reordered.enumerated() where category.sortOrder != index {
                try await client
                    .from("categories")
                    .update(["sort_order": index])
                    .eq("id", value: category.id.uuidString)
                    .execute()
            }
            await self.reload()
        }
    }

    // MARK: - 便利な調べもの

    var me: Member? {
        members.first { $0.userId == userId }
    }

    /// 自分が管理者（家計簿を作った人）か。管理者が決まっていない古い家計簿では、全員を管理者として扱います。
    var isOwner: Bool {
        guard let household else { return false }
        return household.ownerId == nil || household.ownerId == userId
    }

    func memberName(_ userId: UUID) -> String {
        members.first { $0.userId == userId }?.displayName ?? "（退出したメンバー）"
    }

    func categoryName(_ categoryId: UUID?) -> String {
        guard let categoryId else { return "項目なし" }
        return categories.first { $0.id == categoryId }?.name ?? "項目なし"
    }

    /// その人の、その項目の目標金額
    func target(categoryId: UUID, userId: UUID) -> Int {
        targets.first { $0.categoryId == categoryId && $0.userId == userId }?.amount ?? 0
    }

    // MARK: - 内部の道具

    /// Supabaseとのやり取りを実行し、失敗したらエラーの文章を出します。成功したら true を返します。
    @discardableResult
    private func run(_ work: () async throws -> Void) async -> Bool {
        do {
            try await work()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func clearData() {
        household = nil
        members = []
        categories = []
        targets = []
        expenses = []
        monthlySpent = [:]
    }
}

// MARK: - Supabaseに送るデータの形

private struct NewCategory: Encodable {
    let householdId: UUID
    let name: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case name
        case householdId = "household_id"
        case sortOrder = "sort_order"
    }
}

private struct SaveExpenseParams: Encodable {
    struct Share: Encodable {
        let userId: UUID
        let amount: Int

        enum CodingKeys: String, CodingKey {
            case amount
            case userId = "user_id"
        }
    }

    let id: UUID?
    let categoryId: UUID?
    let amount: Int
    let spentOn: String
    let memo: String
    let shares: [Share]

    enum CodingKeys: String, CodingKey {
        case id = "p_id"
        case categoryId = "p_category_id"
        case amount = "p_amount"
        case spentOn = "p_spent_on"
        case memo = "p_memo"
        case shares = "p_shares"
    }

    // nil のときも「null」として送る必要があるので、自分で書いています。
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(categoryId, forKey: .categoryId)
        try container.encode(amount, forKey: .amount)
        try container.encode(spentOn, forKey: .spentOn)
        try container.encode(memo, forKey: .memo)
        try container.encode(shares, forKey: .shares)
    }
}
