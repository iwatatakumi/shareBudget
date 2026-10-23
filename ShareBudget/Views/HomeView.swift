import SwiftData
import SwiftUI

// 今月の項目ごとの「目標・使った額・残り」と、このままいけば貯まる旅行資金を表示する画面です。
struct HomeView: View {
    @Query(sort: \BudgetCategory.sortOrder) private var categories: [BudgetCategory]
    @Query private var allExpenses: [Expense]

    private var currentSummary: MonthlySummary {
        MonthlySummary(
            categories: categories,
            expenses: allExpenses.filter { $0.date.isInCurrentMonth }
        )
    }

    var body: some View {
        let summary = currentSummary

        NavigationStack {
            List {
                Section {
                    MonthOverview(summary: summary)
                }

                Section("項目ごと") {
                    ForEach(summary.categories) { item in
                        CategoryProgressRow(item: item)
                    }
                    if summary.uncategorizedSpent > 0 {
                        HStack {
                            Text("項目なし")
                            Spacer()
                            Text(summary.uncategorizedSpent.yenText)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if summary.totalTarget == 0 {
                    Section {
                        Text("「設定」タブで項目ごとの目標金額を決めると、残りと旅行資金が計算されます。")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(Date().formatted(.dateTime.month(.wide)) + "の家計簿")
        }
    }
}

// 画面上部の、今月全体のまとめです。
private struct MonthOverview: View {
    let summary: MonthlySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.totalRemaining >= 0 ? "今月の残り" : "今月の目標オーバー")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(abs(summary.totalRemaining).yenText)
                    .font(.largeTitle.bold())
                    .foregroundStyle(summary.totalRemaining >= 0 ? Color.primary : Color.red)
            }

            HStack {
                LabeledValue(title: "目標の合計", value: summary.totalTarget)
                Spacer()
                LabeledValue(title: "使った額", value: summary.totalSpent)
            }

            Label {
                Text("このままいけば旅行資金 \(summary.projectedTravelFund.signedYenText)")
            } icon: {
                Image(systemName: "airplane")
            }
            .font(.callout.bold())
            .foregroundStyle(summary.projectedTravelFund >= 0 ? Color.accentColor : Color.red)
        }
        .padding(.vertical, 4)
    }
}

private struct LabeledValue: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.yenText)
                .font(.headline)
        }
    }
}

// 項目1つぶんの行です。使った割合をバーで表示します。
private struct CategoryProgressRow: View {
    let item: CategorySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name)
                    .font(.headline)
                Spacer()
                if item.isOver {
                    Text("\((-item.remaining).yenText)オーバー")
                        .foregroundStyle(.red)
                } else {
                    Text("残り \(item.remaining.yenText)")
                }
            }

            // バーの長さ = 使った額 ÷ 目標金額（目標を超えたら満タン）
            ProgressView(
                value: Double(min(item.spent, max(item.target, 1))),
                total: Double(max(item.target, 1))
            )
            .tint(item.isOver ? .red : .accentColor)

            Text("使った額 \(item.spent.yenText) ／ 目標 \(item.target.yenText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HomeView()
        .modelContainer(PreviewData.container)
}
