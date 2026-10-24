import SwiftUI

// 今月の家計簿の様子を表示する画面です。
// 家計簿全体、メンバーごと、項目ごとに「目標・使った額・目標との差」を出します。
struct HomeView: View {
    @Environment(BudgetStore.self) private var store

    var body: some View {
        let summary = MonthlySummary(store: store)

        NavigationStack {
            List {
                Section {
                    MonthOverview(summary: summary)
                }

                if store.members.count > 1 {
                    Section {
                        ForEach(summary.members) { member in
                            MemberRow(member: member)
                        }
                    } header: {
                        Text("メンバーごと")
                    } footer: {
                        Text("使った額は、支出のうちその人が負担する分（配分）の合計です。")
                    }
                }

                Section("項目ごと") {
                    ForEach(summary.categories) { item in
                        CategoryProgressRow(
                            item: item,
                            daily: summary.daily,
                            showsMembers: store.members.count > 1
                        )
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
            // 下に引っぱると、ルームメイトが入力した支出も読み込み直します。
            .refreshable {
                await store.reload()
            }
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

            if summary.totalTarget > 0 {
                DailyOverview(summary: summary)
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

// 1日あたりの目標と、今日・今日までの使った額です。
private struct DailyOverview: View {
    let summary: MonthlySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                LabeledValue(title: "1日あたりの目標", value: summary.dailyTarget)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    LabeledValue(title: "今日の支出", value: summary.todaySpent)
                    DifferenceText(difference: summary.dailyTarget - summary.todaySpent)
                        .font(.caption)
                }
            }
            Text("目標の合計 \(summary.totalTarget.yenText) ÷ \(summary.daily.daysInMonth)日")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text("今日（\(summary.daily.today)日）までの目標 \(summary.targetUntilToday.yenText)")
                Spacer()
                DifferenceText(difference: summary.targetUntilToday - summary.totalSpent)
            }
            .font(.caption)
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
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

// メンバー1人ぶんの、今月の目標・使った額・目標との差です。
private struct MemberRow: View {
    let member: MemberSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(member.name)
                    .font(.headline)
                Spacer()
                DifferenceText(difference: member.difference)
            }
            Text("使った額 \(member.spent.yenText) ／ 目標 \(member.target.yenText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// 目標との差を「残り 〇円」または「〇円オーバー」と表示します。
private struct DifferenceText: View {
    let difference: Int

    var body: some View {
        if difference >= 0 {
            Text("残り \(difference.yenText)")
        } else {
            Text("\((-difference).yenText)オーバー")
                .foregroundStyle(.red)
        }
    }
}

// 項目1つぶんの行です。使った割合をバーで表示し、その下に人ごとの内訳を出します。
private struct CategoryProgressRow: View {
    let item: CategorySummary
    let daily: DailyBudget
    let showsMembers: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.name)
                    .font(.headline)
                Spacer()
                DifferenceText(difference: item.remaining)
            }

            // バーの長さ = 使った額 ÷ 目標金額（目標を超えたら満タン）
            ProgressView(
                value: Double(min(item.spent, max(item.target, 1))),
                total: Double(max(item.target, 1))
            )
            .tint(item.isOver ? .red : .accentColor)

            Text("使った額 \(item.spent.yenText) ／ 目標 \(item.target.yenText)（1日 \(daily.perDay(item.target).yenText)）")
                .font(.caption)
                .foregroundStyle(.secondary)

            if showsMembers {
                ForEach(item.members) { member in
                    HStack {
                        Text("・\(member.name)：\(member.spent.yenText) ／ \(member.target.yenText)")
                        Spacer()
                        DifferenceText(difference: member.difference)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HomeView()
        .environment(PreviewData.store)
}
