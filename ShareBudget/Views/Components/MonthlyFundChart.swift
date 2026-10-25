import Charts
import SwiftUI

// 月ごとに貯まった旅行資金の棒グラフです。プラスの月は青、マイナスの月はオレンジで、上下に伸びます。
struct MonthlyFundChart: View {
    /// 新しい月から順番（TravelFund.months と同じ）
    let months: [MonthlyFund]

    @State private var selectedMonth: String?
    @State private var appeared = false

    /// 古い月から順番に並べ直したもの（グラフは左が古い月）
    private var ordered: [MonthlyFund] {
        Array(months.reversed())
    }

    private var selected: MonthlyFund? {
        months.first { $0.month == selectedMonth }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 指でなぞった月の金額（なぞっていなければ一番新しい月）
            let shown = selected ?? months.first
            if let shown {
                HStack(alignment: .firstTextBaseline) {
                    Text(shown.isCurrent ? "\(shown.title)（今日まで）" : shown.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(shown.fund.signedYenText)
                        .font(.headline)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .foregroundStyle(Theme.goldGradient)
                }
            }

            Chart {
                ForEach(ordered) { month in
                    BarMark(
                        x: .value("月", month.month),
                        y: .value("旅行資金", appeared ? month.fund : 0),
                        width: .ratio(0.6)
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Theme.glossy(month.fund >= 0 ? Theme.positive : Theme.negative, startPoint: .leading, endPoint: .trailing))
                    .opacity(selectedMonth == nil || selectedMonth == month.month ? 1 : 0.4)
                }

                RuleMark(y: .value("ゼロ", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let month = value.as(String.self) {
                            Text(shortTitle(month))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let yen = value.as(Int.self) {
                            Text(compactYen(yen))
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedMonth)
            .shadow(color: .black.opacity(0.4), radius: 6, y: 4)
            .frame(height: 180)
            .animation(.spring(duration: 0.8), value: appeared)
            .onAppear { appeared = true }
        }
        .padding(.vertical, 6)
    }

    /// グラフの下に出す短い月の名前（"2026-10" → 10月。1月だけ年も付けます）
    private func shortTitle(_ month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let number = Int(parts[1]) else { return month }
        return number == 1 ? "\(year % 100)年1月" : "\(number)月"
    }

    /// 目盛りの金額を短くします（例: 12000 → 1.2万）
    private func compactYen(_ yen: Int) -> String {
        if abs(yen) >= 10_000 {
            let man = Double(yen) / 10_000
            return man == man.rounded() ? "\(Int(man))万" : String(format: "%.1f万", man)
        }
        return "\(yen)"
    }
}
