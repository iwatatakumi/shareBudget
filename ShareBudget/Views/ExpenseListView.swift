import SwiftUI

struct ExpenseListView: View {
    var body: some View {
        PlaceholderView(
            title: "支出の一覧",
            systemImage: "list.bullet",
            message: "今月の支出が新しい順に並び、修正や削除ができるようになります。"
        )
    }
}

#Preview {
    ExpenseListView()
}
