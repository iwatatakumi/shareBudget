import SwiftUI

struct TravelFundView: View {
    var body: some View {
        PlaceholderView(
            title: "旅行資金",
            systemImage: "airplane",
            message: "月ごとに貯まった旅行資金の履歴と合計がここに表示されます。"
        )
    }
}

#Preview {
    TravelFundView()
}
