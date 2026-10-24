import Foundation

// 旅行資金タブで使うデータです。

/// 旅行先の候補1つぶん
struct TravelIdea: Codable, Identifiable, Hashable {
    /// 都市の名前（例: 台北）
    var city: String
    /// 国の名前（例: 台湾）
    var country: String
    /// 旅行ルート（例: 台北 → 九份 → 台北）
    var route: String
    /// 旅行の日数
    var days: Int
    /// 1人あたりの費用の目安（円）
    var costPerPerson: Int
    /// 費用の内訳など
    var costNote: String
    /// 見どころ
    var highlights: [String]

    var id: String { city + route }

    enum CodingKeys: String, CodingKey {
        case city, country, route, days, highlights
        case costPerPerson = "cost_per_person"
        case costNote = "cost_note"
    }
}

/// AIが探した旅行先の候補（家計簿ごとに1つ保存されます）
struct TravelSuggestions: Codable {
    let householdId: UUID
    var ideas: [TravelIdea]
    /// 探した日時（"2026-10-24T16:40:00+00:00" のような文字）
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case ideas
        case householdId = "household_id"
        case createdAt = "created_at"
    }

    /// 探した日時を Date 型にしたもの
    var createdDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: createdAt) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: createdAt)
    }
}

/// 月ごとの支出の合計（データベースの monthly_spent 関数の結果）
struct MonthlySpent: Decodable {
    /// "2026-10" の形の文字
    let month: String
    let total: Int
}

/// 1か月ぶんの旅行資金
struct MonthlyFund: Identifiable {
    /// "2026-10" の形の文字
    let month: String
    let target: Int
    let spent: Int
    /// 今月（まだ途中の月）かどうか
    let isCurrent: Bool

    var id: String { month }
    /// この月に貯まった旅行資金（マイナスなら目標オーバー）
    var fund: Int { target - spent }

    /// 「2026年10月」のような表示用の文字
    var title: String {
        let parts = month.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else { return self.month }
        return "\(year)年\(month)月"
    }
}

/// 貯まった旅行資金の合計と、月ごとの記録
struct TravelFund {
    /// 新しい月から順番
    let months: [MonthlyFund]

    /// 貯まった旅行資金の合計（マイナスの月も引きます）
    var total: Int {
        months.reduce(0) { $0 + $1.fund }
    }

    /// 家計簿を作った月から今月までを計算します。
    /// 終わった月は「1か月の目標 − その月に使った額」、今月は「今日までの目標 − 使った額」です。
    /// 過去の月も、いまの目標金額で計算します。
    @MainActor
    init(store: BudgetStore, now: Date = Date()) {
        let summary = MonthlySummary(store: store, now: now)
        let calendar = Calendar.current
        let currentMonth = String(DayString.string(from: now).prefix(7))

        var months = [
            MonthlyFund(
                month: currentMonth,
                target: summary.targetUntilToday,
                spent: summary.totalSpent,
                isCurrent: true
            ),
        ]

        // 家計簿を作った月（"2026-10-24T..." の最初の7文字）
        let startMonth = store.household.map { String($0.createdAt.prefix(7)) } ?? currentMonth
        if var date = DayString.date(from: currentMonth + "-01") {
            while true {
                guard let previous = calendar.date(byAdding: .month, value: -1, to: date) else { break }
                let month = String(DayString.string(from: previous).prefix(7))
                guard month >= startMonth else { break }
                months.append(MonthlyFund(
                    month: month,
                    target: summary.totalTarget,
                    spent: store.monthlySpent[month] ?? 0,
                    isCurrent: false
                ))
                date = previous
            }
        }
        self.months = months
    }
}

extension TravelIdea {
    /// AIで探す前に表示する、アプリに入っている参考の候補です。
    /// 日本発・1人あたりのおおまかな目安で、実際の費用は時期によって大きく変わります。
    static let samples: [TravelIdea] = [
        TravelIdea(
            city: "ソウル", country: "韓国", route: "ソウル（明洞・景福宮）→ 北村韓屋村",
            days: 3, costPerPerson: 70_000,
            costNote: "往復航空券 約3万円・ホテル2泊 約2万円・食費や交通 約2万円",
            highlights: ["屋台グルメ", "韓服で古宮めぐり"]
        ),
        TravelIdea(
            city: "台北", country: "台湾", route: "台北 → 九份 → 台北（夜市）",
            days: 4, costPerPerson: 100_000,
            costNote: "往復航空券 約4万円・ホテル3泊 約3万円・食費や交通 約3万円",
            highlights: ["九份の夜景", "士林夜市"]
        ),
        TravelIdea(
            city: "バンコク", country: "タイ", route: "バンコク → アユタヤ日帰り",
            days: 5, costPerPerson: 120_000,
            costNote: "往復航空券 約6万円・ホテル4泊 約3万円・食費や交通 約3万円",
            highlights: ["寺院めぐり", "水上マーケット"]
        ),
        TravelIdea(
            city: "ハノイ", country: "ベトナム", route: "ハノイ → ハロン湾クルーズ → ハノイ",
            days: 5, costPerPerson: 130_000,
            costNote: "往復航空券 約6万円・ホテル4泊 約3万円・クルーズや食費 約4万円",
            highlights: ["ハロン湾の絶景", "フォーの食べ歩き"]
        ),
        TravelIdea(
            city: "ホノルル", country: "アメリカ（ハワイ）", route: "ホノルル（ワイキキ）→ ノースショア",
            days: 6, costPerPerson: 300_000,
            costNote: "往復航空券 約12万円・ホテル4泊 約12万円・食費や交通 約6万円",
            highlights: ["ダイヤモンドヘッド", "ビーチ"]
        ),
        TravelIdea(
            city: "パリ", country: "フランス", route: "パリ → モン・サン・ミッシェル → パリ",
            days: 8, costPerPerson: 450_000,
            costNote: "往復航空券 約20万円・ホテル6泊 約15万円・食費や交通 約10万円",
            highlights: ["美術館めぐり", "モン・サン・ミッシェル"]
        ),
    ]
}
