import SwiftUI

struct AddExpenseView: View {
    var body: some View {
        PlaceholderView(
            title: "支出の入力",
            systemImage: "plus.circle",
            message: "金額・項目・日付・メモを入れて支出を保存する画面です。"
        )
    }
}

#Preview {
    AddExpenseView()
}
