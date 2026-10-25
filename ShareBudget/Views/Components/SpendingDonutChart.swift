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
                // 細くシャープな輪にします（内側の半径 0.82、外側の半径 0.94）。
                // なぞっている切れだけ、少し太く外に飛び出します。
                SectorMark(
                    angle: .value("金額", slice.amount),
                    innerRadius: .ratio(selectedSlice?.id == slice.id ? 0.78 : 0.82),
                    outerRadius: .ratio(selectedSlice?.id == slice.id ? 1.0 : 0.94),
                    angularInset: 2
                )
                .cornerRadius(2)
                // 金属や宝石のように光を反射する、深みのある色にします
                .foregroundStyle(Theme.metallic(slice.color))
                .opacity(selectedSlice == nil || selectedSlice?.id == slice.id ? 1 : 0.35)
            }
            .chartAngleSelection(value: $selectedValue)
            .chartBackground { _ in
                centerLabel
            }
            // 輪の内側と外側の金色の細い線と、光が反射しているような白いツヤを重ねます
            .overlay { DonutGloss().allowsHitTesting(false) }
            // 輪の下に落ちる影と、ふんわり光る金色で、浮き上がって見せます
            .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
            .shadow(color: Theme.gold.opacity(0.18), radius: 16)
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
                .foregroundStyle(Theme.goldGradient)
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
                        .fill(Theme.metallic(slice.color))
                        .frame(width: 12, height: 12)
                        .shadow(color: slice.color.opacity(0.7), radius: 3)
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

// ドーナツの輪に重ねる飾りです。
// 輪の外側と内側に金色の細い線を引き、輪の上半分には光が反射しているような白いツヤを重ねます。
private struct DonutGloss: View {
    var body: some View {
        GeometryReader { geometry in
            // グラフの輪の大きさ（SectorMark の outerRadius 0.94 / innerRadius 0.82 に合わせます）
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack {
                // 光のツヤ
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.05), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: radius * 0.12
                    )
                    .frame(width: radius * 1.88, height: radius * 1.88)
                    .blendMode(.screen)

                // 外側の金色の線
                Circle()
                    .stroke(Theme.goldRing, lineWidth: 1)
                    .frame(width: radius * 2.0, height: radius * 2.0)
                    .opacity(0.8)

                // 内側の金色の線
                Circle()
                    .stroke(Theme.goldRing, lineWidth: 0.8)
                    .frame(width: radius * 1.56, height: radius * 1.56)
                    .opacity(0.6)
            }
            .position(center)
        }
    }
}
