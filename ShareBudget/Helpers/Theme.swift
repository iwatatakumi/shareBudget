import SwiftUI
import UIKit

// アプリ全体の色をまとめたものです。
// ライトモード（明るい画面）とダークモード（暗い画面）で、見やすい色に自動で切り替わります。
enum Theme {
    /// 項目に順番に割り当てる8色（目の色の感じ方が違う人にも区別しやすい並び）
    private static let categoryPalette: [(light: UInt32, dark: UInt32)] = [
        (0x2A78D6, 0x3987E5), // 青
        (0xEB6834, 0xD95926), // オレンジ
        (0x1BAF7A, 0x199E70), // 水色がかった緑
        (0xEDA100, 0xC98500), // 黄
        (0xE87BA4, 0xD55181), // ピンク
        (0x008300, 0x008300), // 緑
        (0x6250D6, 0x9085E9), // 紫
        (0xE34948, 0xE66767), // 赤
    ]

    /// 9個目以降の項目や「項目なし」に使う灰色
    static let otherColor = dynamic(light: 0x8A8984, dark: 0x8A8984)

    /// 項目の並び順（0から）に合わせた色。8個を超えた分は灰色にします。
    static func categoryColor(index: Int) -> Color {
        guard categoryPalette.indices.contains(index) else { return otherColor }
        let pair = categoryPalette[index]
        return dynamic(light: pair.light, dark: pair.dark)
    }

    /// 旅行資金がプラスのときの色（青）と、マイナスのときの色（オレンジ）
    static let positive = categoryColor(index: 0)
    static let negative = categoryColor(index: 1)

    /// 画面上部の大きなカードの背景（青から紫へのグラデーション）
    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0x2A78D6), Color(hex: 0x6250D6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 旅行資金タブのカードの背景（水色から青へのグラデーション）
    static let travelGradient = LinearGradient(
        colors: [Color(hex: 0x199E70), Color(hex: 0x2A78D6)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension Color {
    /// 0x2A78D6 のような16進数の数字から色を作ります。
    init(hex: UInt32) {
        self.init(UIColor(hex: hex))
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension BudgetStore {
    /// 項目の色（「設定」の並び順で決まります）。項目なしは灰色です。
    func categoryColor(_ categoryId: UUID?) -> Color {
        guard let index = categories.firstIndex(where: { $0.id == categoryId }) else { return Theme.otherColor }
        return Theme.categoryColor(index: index)
    }
}

// 項目の頭文字を、項目の色の丸の中に入れたアイコンです（一覧などで使います）。
struct CategoryBadge: View {
    let name: String
    let color: Color

    var body: some View {
        Text(String(name.prefix(1)))
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(color.gradient, in: Circle())
    }
}
