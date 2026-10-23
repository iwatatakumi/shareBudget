import SwiftUI

// 支出を新しく入力する画面です。
struct AddExpenseView: View {
    // 保存したら入力欄を空に戻すため、フォームを作り直す目印に使います。
    @State private var formId = UUID()
    @State private var showSavedMessage = false

    var body: some View {
        NavigationStack {
            ExpenseForm(expense: nil) {
                formId = UUID()
                showSavedMessage = true
            }
            .id(formId)
            .navigationTitle("支出の入力")
            .alert("保存しました", isPresented: $showSavedMessage) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}

#Preview {
    AddExpenseView()
        .environment(PreviewData.store)
}
