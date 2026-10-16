import Foundation

extension Int {
    /// 金額を「3,500円」のような形の文字にします。
    var yenText: String {
        formatted(.number) + "円"
    }
}

extension Date {
    /// 今日と同じ月の日付かどうか
    var isInCurrentMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
}
