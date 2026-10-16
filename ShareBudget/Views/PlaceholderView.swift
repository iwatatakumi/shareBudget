import SwiftUI

// まだ作っていない画面に「ここに何が入る予定か」を表示する共通の部品です。
// 中身を作り終えた画面から順番に、この部品を使わなくなっていきます。
struct PlaceholderView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                title,
                systemImage: systemImage,
                description: Text(message)
            )
            .navigationTitle(title)
        }
    }
}
