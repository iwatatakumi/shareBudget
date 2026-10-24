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

    /// 最新の航空券の値段をネットで調べるためのリンク（Googleフライト）
    var flightSearchURL: URL? {
        var components = URLComponents(string: "https://www.google.com/travel/flights")
        components?.queryItems = [URLQueryItem(name: "q", value: "東京 から \(city) 航空券")]
        return components?.url
    }

    enum CodingKeys: String, CodingKey {
        case city, country, route, days, highlights
        case costPerPerson = "cost_per_person"
        case costNote = "cost_note"
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
    /// アプリに入っている旅行先の候補です（無料で使えるように、ネットやAIは使っていません）。
    /// 東京発・1人あたりのおおまかな目安で、実際の費用は時期や予約のしかたで大きく変わります。
    static let samples: [TravelIdea] = [
        TravelIdea(
            city: "ソウル", country: "韓国", route: "ソウル（明洞・景福宮）→ 北村韓屋村",
            days: 3, costPerPerson: 70_000,
            costNote: "往復航空券 約3万円・ホテル2泊 約2万円・食費や交通 約2万円",
            highlights: ["屋台グルメ", "韓服で古宮めぐり"]
        ),
        TravelIdea(
            city: "釜山", country: "韓国", route: "釜山（海雲台）→ 甘川文化村 → チャガルチ市場",
            days: 3, costPerPerson: 65_000,
            costNote: "往復航空券 約3万円・ホテル2泊 約1.5万円・食費や交通 約2万円",
            highlights: ["海鮮", "カラフルな坂の町"]
        ),
        TravelIdea(
            city: "台北", country: "台湾", route: "台北 → 九份 → 台北（夜市）",
            days: 4, costPerPerson: 100_000,
            costNote: "往復航空券 約4万円・ホテル3泊 約3万円・食費や交通 約3万円",
            highlights: ["九份の夜景", "士林夜市"]
        ),
        TravelIdea(
            city: "香港", country: "中国（香港）", route: "香港島 → 九龍 → マカオ日帰り",
            days: 4, costPerPerson: 130_000,
            costNote: "往復航空券 約5万円・ホテル3泊 約5万円・食費や交通 約3万円",
            highlights: ["100万ドルの夜景", "飲茶"]
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
            city: "シンガポール", country: "シンガポール", route: "マリーナベイ → セントーサ島 → チャイナタウン",
            days: 4, costPerPerson: 170_000,
            costNote: "往復航空券 約7万円・ホテル3泊 約6万円・食費や交通 約4万円",
            highlights: ["マリーナベイ・サンズ", "ナイトサファリ"]
        ),
        TravelIdea(
            city: "バリ島", country: "インドネシア", route: "ウブド → クタ → ウルワツ寺院",
            days: 6, costPerPerson: 180_000,
            costNote: "往復航空券 約9万円・ホテル4泊 約5万円・食費や交通 約4万円",
            highlights: ["ライステラス", "夕日とケチャダンス"]
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
        TravelIdea(
            city: "ローマ", country: "イタリア", route: "ローマ → フィレンツェ → ヴェネツィア",
            days: 9, costPerPerson: 480_000,
            costNote: "往復航空券 約20万円・ホテル7泊 約16万円・鉄道や食費 約12万円",
            highlights: ["コロッセオ", "ゴンドラ"]
        ),
        TravelIdea(
            city: "ニューヨーク", country: "アメリカ", route: "マンハッタン → ブルックリン → 自由の女神",
            days: 7, costPerPerson: 500_000,
            costNote: "往復航空券 約22万円・ホテル5泊 約18万円・食費や交通 約10万円",
            highlights: ["ブロードウェイ", "セントラルパーク"]
        ),
    ]
}
