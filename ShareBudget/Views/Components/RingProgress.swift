import SwiftUI

// 進み具合を、ぐるっと一周する輪で表す部品です。
struct RingProgress<Label: View>: View {
    /// 進み具合（0〜1）
    let progress: Double
    let lineWidth: CGFloat
    let gradient: AngularGradient
    @ViewBuilder let label: () -> Label

    @State private var appeared = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: appeared ? min(max(progress, 0), 1) : 0)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                // 輪がぼんやり光って見えるようにします
                .shadow(color: Theme.gold.opacity(0.45), radius: 5)
            label()
        }
        .animation(.spring(duration: 1.0), value: appeared)
        .animation(.spring(duration: 0.6), value: progress)
        .onAppear { appeared = true }
    }
}

extension AngularGradient {
    /// 旅行資金の輪の色（エメラルド、サファイア、アメジスト、金色の宝石のような色）
    static let travel = AngularGradient(
        colors: [Color(hex: 0x199E70), Color(hex: 0x3987E5), Color(hex: 0x9085E9), Color(hex: 0xE8C36A), Color(hex: 0x199E70)],
        center: .center
    )
}
