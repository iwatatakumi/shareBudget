import Foundation
import SwiftData

// Xcodeのプレビュー（右側に出る画面の見本）で使う、お試し用のデータです。
// 本物のデータには影響しません。
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Expense.self, BudgetCategory.self,
            configurations: configuration
        )
        let context = container.mainContext

        BudgetCategory.insertDefaultsIfNeeded(into: context)
        let categories = (try? context.fetch(
            FetchDescriptor<BudgetCategory>(sortBy: [SortDescriptor(\.sortOrder)])
        )) ?? []

        context.insert(Expense(amount: 1200, date: Date(), memo: "スーパー", category: categories.first))
        context.insert(Expense(amount: 580, date: Date(), memo: "", category: categories.dropFirst().first))
        return container
    }()
}
