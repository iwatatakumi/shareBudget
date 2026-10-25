import SwiftUI

// アプリを起動したときに出る、タイトルの演出画面です。
// 金色の輪が描かれ、その中を飛行機が飛び、「シェアバジェット」の文字が光りながら浮かび上がります。
struct SplashView: View {
    /// 輪が描かれていく進み具合（0〜1）
    @State private var ringProgress: CGFloat = 0
    /// 飛行機が輪の上を進む角度
    @State private var planeAngle: Double = -90
    /// タイトルの文字が出てきたか
    @State private var showsTitle = false
    /// 文字の上を光が横切るアニメーション用（-1 から 1 へ動かします）
    @State private var shinePhase: CGFloat = -1

    var body: some View {
        ZStack {
            LuxuryBackground()

            VStack(spacing: 28) {
                ZStack {
                    // うっすら見える輪の下地
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 3)

                    // 金色の輪が、ぐるっと描かれていきます
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(Theme.goldRing, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Theme.gold.opacity(0.7), radius: 6)

                    // 輪の上を回る飛行機
                    Image(systemName: "airplane")
                        .font(.title2)
                        .foregroundStyle(Theme.goldGradient)
                        .shadow(color: Theme.gold.opacity(0.8), radius: 6)
                        // 輪に沿って進む向きに機首を向けます（外側の回転と合わせて、ちょうど進行方向になります）
                        .rotationEffect(.degrees(90))
                        .offset(x: 70)
                        .rotationEffect(.degrees(planeAngle))

                    // 真ん中の円グラフのようなマーク
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.goldGradient)
                        .scaleEffect(showsTitle ? 1 : 0.4)
                        .opacity(showsTitle ? 1 : 0)
                }
                .frame(width: 140, height: 140)

                VStack(spacing: 8) {
                    Text("シェアバジェット")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.goldGradient)
                        // 文字の形に合わせて、光の帯を重ねます
                        .overlay {
                            GeometryReader { geometry in
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.8), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: geometry.size.width * 0.35)
                                .offset(x: shinePhase * geometry.size.width)
                            }
                            .mask {
                                Text("シェアバジェット")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                            }
                        }
                        .shadow(color: Theme.gold.opacity(0.5), radius: 10)

                    Text("家計簿共有アプリ")
                        .font(.subheadline)
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.75))
                }
                // 下から、ふわっと浮かび上がります
                .opacity(showsTitle ? 1 : 0)
                .offset(y: showsTitle ? 0 : 16)
                .blur(radius: showsTitle ? 0 : 6)
            }
        }
        .onAppear(perform: animate)
    }

    private func animate() {
        withAnimation(.easeInOut(duration: 1.2)) {
            ringProgress = 1
            planeAngle = 270
        }
        withAnimation(.spring(duration: 0.9).delay(0.5)) {
            showsTitle = true
        }
        withAnimation(.easeInOut(duration: 0.9).delay(1.2)) {
            shinePhase = 1.2
        }
    }
}

#Preview {
    SplashView()
}
