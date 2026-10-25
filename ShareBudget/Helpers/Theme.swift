import SwiftUI
import UIKit

// アプリ全体の色をまとめたものです。
// アプリは高級感が出るように、いつも暗い画面（ダークモード）で表示します。
enum Theme {
    /// 項目に順番に割り当てる8色。宝石や金属のような、深みのある色です。
    /// 隣どうしの色は、目の色の感じ方が違う人にも区別しやすい並びにしています。
    private static let categoryPalette: [(light: UInt32, dark: UInt32)] = [
        (0x3A6FD8, 0x3A6FD8), // サファイア（青）
        (0xC0703A, 0xC0703A), // カッパー（銅色）
        (0x1E9E74, 0x1E9E74), // エメラルド（緑）
        (0x8A63D2, 0x8A63D2), // アメジスト（紫）
        (0xB08A38, 0xB08A38), // ゴールド（金色）
        (0xC2416A, 0xC2416A), // ルビー（赤）
        (0x2A9BB0, 0x2A9BB0), // アクアマリン（青緑）
        (0xD35F8C, 0xD35F8C), // ローズ（ピンク）
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

    /// 画面上部の大きなカードの背景（サファイアの青から紫、ワインレッドへのグラデーション）
    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0x1F2F75), Color(hex: 0x47298A), Color(hex: 0x7A2A66)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 旅行資金タブのカードの背景（エメラルドの緑からサファイアの青へのグラデーション）
    static let travelGradient = LinearGradient(
        colors: [Color(hex: 0x0D5A52), Color(hex: 0x173F86), Color(hex: 0x3A2A80)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 金色（ボタンや強調する文字に使います）
    static let gold = Color(hex: 0xE8C36A)

    /// 金属のような光沢のある金色（明るい所と暗い所を交互に並べると、光って見えます）
    static let goldGradient = LinearGradient(
        colors: [Color(hex: 0xFBEBB5), Color(hex: 0xD9A949), Color(hex: 0xF5D98A), Color(hex: 0xB8862F)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 金色の輪（ぐるっと一周するグラデーション）
    static let goldRing = AngularGradient(
        colors: [Color(hex: 0xB8862F), Color(hex: 0xFBEBB5), Color(hex: 0xD9A949), Color(hex: 0xF5D98A), Color(hex: 0xB8862F)],
        center: .center
    )

    /// 一覧の1行ぶんの背景（うしろが少し透けて見える、すりガラスのような色）
    static let glassRow = Color.white.opacity(0.07)

    /// 金属のような光沢を出したグラデーション。
    /// 明るい所と暗い所を交互に並べると、光を反射する金属や宝石のように見えます。
    static func metallic(_ color: Color) -> LinearGradient {
        let base = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        return LinearGradient(
            stops: [
                .init(color: Color(base.mixed(with: .white, amount: 0.5)), location: 0),
                .init(color: Color(base), location: 0.35),
                .init(color: Color(base.mixed(with: .black, amount: 0.35)), location: 0.6),
                .init(color: Color(base.mixed(with: .white, amount: 0.2)), location: 0.85),
                .init(color: Color(base.mixed(with: .black, amount: 0.2)), location: 1),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 色に「ツヤ」を出したグラデーション。
    /// 上を白っぽく（光が当たっている所）、下を少し暗く（影）すると、立体的でツヤがあるように見えます。
    static func glossy(_ color: Color, startPoint: UnitPoint = .top, endPoint: UnitPoint = .bottom) -> LinearGradient {
        // アプリはいつも暗い画面（ダークモード）なので、ダークモードの色を使います
        let base = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        return LinearGradient(
            stops: [
                .init(color: Color(base.mixed(with: .white, amount: 0.45)), location: 0),
                .init(color: Color(base), location: 0.5),
                .init(color: Color(base.mixed(with: .black, amount: 0.3)), location: 1),
            ],
            startPoint: startPoint,
            endPoint: endPoint
        )
    }

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

    /// ほかの色（白や黒）を amount の割合（0〜1）で混ぜた色
    func mixed(with other: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * amount,
            green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount,
            alpha: a1
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
            .background(Theme.glossy(color), in: Circle())
            .overlay(Circle().strokeBorder(Theme.gold.opacity(0.6), lineWidth: 1))
            .shadow(color: color.opacity(0.5), radius: 4, y: 2)
    }
}

// アプリ全体の背景です。夜空のような濃い紺から紫へのグラデーションに、
// 右上に金色、左下に紫の光がぼんやり差しているように見せます。
struct LuxuryBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0A0E24), Color(hex: 0x141235), Color(hex: 0x1F0C2C)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Theme.gold.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 420
            )
            RadialGradient(
                colors: [Color(hex: 0x6250D6).opacity(0.28), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
    }
}

// 大きなカードの背景です。グラデーションの上に金色の細い縁取りと、
// ときどき光がすっと横切る（きらっと光る）アニメーションを重ねます。
struct GlossyCardBackground: View {
    let gradient: LinearGradient

    var body: some View {
        ZStack {
            gradient
            // 左上から光が当たっているように見せる、白いぼかし
            RadialGradient(
                colors: [.white.opacity(0.22), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 260
            )
            ShimmerOverlay()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Theme.goldGradient, lineWidth: 1.2)
        )
    }
}

// 光の帯が、左から右へゆっくり通り過ぎるアニメーションです。
struct ShimmerOverlay: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [.clear, .white.opacity(0.16), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 0.45, height: geometry.size.height * 2)
            .rotationEffect(.degrees(20))
            .offset(x: phase * geometry.size.width, y: -geometry.size.height / 2)
        }
        .clipped()
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.linear(duration: 4).delay(0.6).repeatForever(autoreverses: false)) {
                phase = 1.6
            }
        }
    }
}

// List（一覧）を、ゴージャスな背景とすりガラスの行で表示するための部品です。
// List { ... } の代わりに LuxuryList { ... } と書くだけで使えます。
struct LuxuryList<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        List {
            Group { content }
                .listRowBackground(Theme.glassRow)
        }
        .luxuryBackground()
    }
}

// Form（入力画面）用の同じ部品です。
struct LuxuryForm<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Form {
            Group { content }
                .listRowBackground(Theme.glassRow)
        }
        .luxuryBackground()
    }
}

extension View {
    /// List や Form のもともとの灰色の背景を消して、ゴージャスな背景にします。
    func luxuryBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(LuxuryBackground())
    }
}
