import Foundation

// Supabaseのテーブル1行ぶんを表す型です。
// CodingKeys は「Swiftでの名前」と「データベースの列の名前」の対応表です。

/// 家計簿（ルームメイトと共有する単位）
struct Household: Codable, Identifiable {
    let id: UUID
    var name: String
    let inviteCode: String
    /// 管理者（家計簿を作った人）
    var ownerId: UUID?
    /// 作った日時（"2026-10-24T07:50:00+00:00" のような文字）
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case inviteCode = "invite_code"
        case ownerId = "owner_id"
        case createdAt = "created_at"
    }
}

/// 家計簿のメンバー
struct Member: Codable, Identifiable {
    let householdId: UUID
    let userId: UUID
    var displayName: String

    var id: UUID { userId }

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case userId = "user_id"
        case displayName = "display_name"
    }
}

/// 項目（食費など）
struct BudgetCategory: Codable, Identifiable {
    let id: UUID
    let householdId: UUID
    var name: String
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case householdId = "household_id"
        case sortOrder = "sort_order"
    }
}

/// 人ごと・項目ごとの1か月の目標金額
struct MemberTarget: Codable {
    let categoryId: UUID
    let userId: UUID
    let householdId: UUID
    var amount: Int

    enum CodingKeys: String, CodingKey {
        case amount
        case categoryId = "category_id"
        case userId = "user_id"
        case householdId = "household_id"
    }
}

/// 支出の配分（その支出のうち、誰がいくら負担するか）
struct ExpenseShare: Codable, Hashable {
    let userId: UUID
    let amount: Int

    enum CodingKeys: String, CodingKey {
        case amount
        case userId = "user_id"
    }
}

/// 支出
struct Expense: Codable, Identifiable {
    let id: UUID
    let householdId: UUID
    var categoryId: UUID?
    var amount: Int
    /// 使った日（"2026-10-23" の形の文字）
    var spentOn: String
    var memo: String
    let createdBy: UUID
    var shares: [ExpenseShare]

    enum CodingKeys: String, CodingKey {
        case id, amount, memo
        case householdId = "household_id"
        case categoryId = "category_id"
        case spentOn = "spent_on"
        case createdBy = "created_by"
        case shares = "expense_shares"
    }

    /// 使った日を Date 型にしたもの
    var date: Date {
        DayString.date(from: spentOn) ?? Date()
    }

    /// この支出のうち、その人が負担する金額
    func share(of userId: UUID) -> Int {
        shares.first { $0.userId == userId }?.amount ?? 0
    }
}

/// 日付と "2026-10-23" の形の文字を変換します。
enum DayString {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        formatter.date(from: string)
    }

    /// 今月の1日と、来月の1日
    static func currentMonthRange(now: Date = Date()) -> (start: String, end: String) {
        let calendar = Calendar.current
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? now
        return (string(from: start), string(from: end))
    }
}
