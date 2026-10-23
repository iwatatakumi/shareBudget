import Foundation

// 支出を「誰がいくら負担するか」に分ける決まりです。
enum SplitMode: String, CaseIterable, Identifiable {
    /// 人数で均等に分ける
    case equal
    /// 自分だけが負担する
    case onlyMe
    /// 人ごとに金額を入れる
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .equal: "均等"
        case .onlyMe: "自分だけ"
        case .custom: "金額を指定"
        }
    }
}

enum ShareSplit {
    /// 配分を計算します。うまく分けられないとき（指定した金額の合計が合わないなど）は nil を返します。
    /// - Parameters:
    ///   - amount: 支出の金額
    ///   - memberIds: 家計簿のメンバー
    ///   - me: 自分
    ///   - customAmounts: 「金額を指定」のときに入力された金額
    static func shares(
        amount: Int,
        mode: SplitMode,
        memberIds: [UUID],
        me: UUID,
        customAmounts: [UUID: Int]
    ) -> [UUID: Int]? {
        guard amount > 0, !memberIds.isEmpty else { return nil }

        switch mode {
        case .onlyMe:
            return [me: amount]

        case .equal:
            // 割り切れない端数は自分が負担します（例: 1,001円を2人 → 自分501円、相手500円）
            let each = amount / memberIds.count
            let remainder = amount - each * memberIds.count
            var result: [UUID: Int] = [:]
            for id in memberIds {
                result[id] = each
            }
            result[me, default: 0] += remainder
            return result

        case .custom:
            let total = memberIds.reduce(0) { $0 + (customAmounts[$1] ?? 0) }
            guard total == amount else { return nil }
            var result: [UUID: Int] = [:]
            for id in memberIds {
                result[id] = customAmounts[id] ?? 0
            }
            return result
        }
    }
}
