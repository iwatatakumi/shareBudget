import SwiftUI

// 「目標金額」を枠、「使った額」を色の帯で表すバーです。
// 目標より少なければ、残りの部分（旅行資金になる分）が薄い色で見えます。
// 目標を超えると、バー全体が赤くなります。
struct BudgetBar: View {
    let spent: Int
    let target: Int
    let color: Color

    /// 表示のときに、帯が左から伸びるアニメーション用
    @State private var appeared = false

    private var isOver: Bool { spent > target }

    /// 使った割合（0〜1）
    private var ratio: CGFloat {
        guard target > 0 else { return spent > 0 ? 1 : 0 }
        return min(CGFloat(spent) / CGFloat(target), 1)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 目標金額の枠（残りの部分は、旅行資金になる分）
                Capsule()
                    .fill(color.opacity(0.15))

                // 使った額の帯
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: isOver ? [.orange, .red] : [color.opacity(0.75), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(appeared ? geometry.size.width * ratio : 0, ratio > 0 ? 8 : 0))
            }
        }
        .frame(height: 10)
        .animation(.spring(duration: 0.8), value: appeared)
        .animation(.spring(duration: 0.5), value: ratio)
        .onAppear { appeared = true }
    }
}
