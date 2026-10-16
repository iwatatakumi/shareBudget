import SwiftUI

struct HomeView: View {
    var body: some View {
        PlaceholderView(
            title: "ホーム",
            systemImage: "house",
            message: "今月の項目ごとの目標・使った額・残りと、旅行資金の合計がここに表示されます。"
        )
    }
}

#Preview {
    HomeView()
}
