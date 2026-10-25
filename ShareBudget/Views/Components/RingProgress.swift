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
            label()
        }
        .animation(.spring(duration: 1.0), value: appeared)
        .animation(.spring(duration: 0.6), value: progress)
        .onAppear { appeared = true }
    }
}

extension AngularGradient {
    /// 旅行資金の輪の色（水色から青、紫へ）
    static let travel = AngularGradient(
        colors: [Color(hex: 0x1BAF7A), Color(hex: 0x2A78D6), Color(hex: 0x6250D6), Color(hex: 0x1BAF7A)],
        center: .center
    )
}
