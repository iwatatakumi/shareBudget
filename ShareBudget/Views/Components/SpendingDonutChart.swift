import Charts
import SwiftUI

/// ドーナツ型グラフの1切れぶん
struct DonutSlice: Identifiable {
    let id: String
    let name: String
    let amount: Int
    let color: Color
}

// 支出の割合を表すドーナツ型のグラフです（Swift Charts という、Apple の グラフを描く道具を使っています）。
// 切れ目を指でなぞると、その項目の金額と割合が真ん中に出ます。
struct SpendingDonutChart: View {
    let slices: [DonutSlice]

    /// 指でなぞっている位置（グラフの金額の目盛りで表したもの）
    @State private var selectedValue: Int?
    /// 表示のときに、グラフがふわっと広がるアニメーション用
    @State private var appeared = false

    private var total: Int {
        slices.reduce(0) { $0 + $1.amount }
    }

    /// 指でなぞっている切れ
    private var selectedSlice: DonutSlice? {
        guard let selectedValue else { return nil }
        var running = 0
        for slice in slices {
            running += slice.amount
            if selectedValue <= running { return slice }
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 16) {
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("金額", slice.amount),
                    innerRadius: .ratio(selectedSlice?.id == slice.id ? 0.58 : 0.64),
                    outerRadius: .ratio(selectedSlice?.id == slice.id ? 1.0 : 0.94),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(slice.color)
                .opacity(selectedSlice == nil || selectedSlice?.id == slice.id ? 1 : 0.35)
            }
            .chartAngleSelection(value: $selectedValue)
            .chartBackground { _ in
                centerLabel
            }
            .frame(height: 220)
            .scaleEffect(appeared ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
            .rotationEffect(.degrees(appeared ? 0 : -60))
            .animation(.spring(duration: 0.8), value: appeared)
            .animation(.easeOut(duration: 0.2), value: selectedSlice?.id)
            .onAppear { appeared = true }

            legend
        }
        .padding(.vertical, 8)
    }

    // 真ん中に出す文字（なぞっている項目、またはその月の合計）
    private var centerLabel: some View {
        VStack(spacing: 2) {
            Text(selectedSlice?.name ?? "今月の支出")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text((selectedSlice?.amount ?? total).yenText)
                .font(.title3.bold())
                .contentTransition(.numericText())
            if let slice = selectedSlice, total > 0 {
                Text(percentText(slice.amount))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // グラフの下の、色と項目名・金額・割合の一覧
    private var legend: some View {
        VStack(spacing: 8) {
            ForEach(slices) { slice in
                HStack(spacing: 8) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 10, height: 10)
                    Text(slice.name)
                        .font(.subheadline)
                    Spacer()
                    Text(slice.amount.yenText)
                        .font(.subheadline)
                        .monospacedDigit()
                    Text(percentText(slice.amount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
    }

    private func percentText(_ amount: Int) -> String {
        guard total > 0 else { return "0%" }
        return "\(Int((Double(amount) / Double(total) * 100).rounded()))%"
    }
}
