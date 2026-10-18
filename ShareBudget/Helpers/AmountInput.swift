import Foundation

// 入力された文字を金額（円）に変える決まりをまとめたものです。
enum AmountInput {
    /// 支出の金額用。1円以上の数字でなければ nil（からっぽ）を返します。
    static func amount(from text: String) -> Int? {
        guard let value = number(from: text), value > 0 else { return nil }
        return value
    }

    /// 目標金額用。空なら0円、0円以上の数字でなければ nil を返します。
    static func target(from text: String) -> Int? {
        if cleaned(text).isEmpty { return 0 }
        guard let value = number(from: text), value >= 0 else { return nil }
        return value
    }

    private static func number(from text: String) -> Int? {
        Int(cleaned(text))
    }

    private static func cleaned(_ text: String) -> String {
        text.replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
