import Foundation

extension Int {
    /// 金額を「3,500円」のような形の文字にします。
    var yenText: String {
        formatted(.number) + "円"
    }

    /// 金額を「+3,500円」「−2,000円」のように、プラス・マイナスの記号付きの文字にします。
    var signedYenText: String {
        if self < 0 {
            return "−" + (-self).yenText
        }
        return "+" + yenText
    }
}

extension Date {
    /// 今日と同じ月の日付かどうか
    var isInCurrentMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
}
