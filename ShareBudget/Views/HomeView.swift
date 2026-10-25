import SwiftUI

// 今月の家計簿の様子を表示する画面です。
// 一番上のカードで今月の残りと旅行資金、グラフで支出の割合、
// その下でメンバーごと・項目ごとの「目標・使った額・目標との差」を出します。
struct HomeView: View {
    @Environment(BudgetStore.self) private var store

    var body: some View {
        let summary = MonthlySummary(store: store)

        NavigationStack {
            List {
                Section {
                    HeroCard(summary: summary)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Theme.heroGradient)
                }

                if summary.totalTarget > 0 {
                    Section("今日のペース") {
                        DailyOverview(summary: summary)
                    }
                }

                Section("支出の割合") {
                    if summary.totalSpent > 0 {
                        SpendingDonutChart(slices: donutSlices(summary))
                    } else {
                        Label("今月の支出を入力すると、ここにグラフが出ます。", systemImage: "chart.pie")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
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

                Section {
                    ForEach(Array(summary.categories.enumerated()), id: \.element.id) { index, item in
                        CategoryProgressRow(
                            item: item,
                            daily: summary.daily,
                            color: Theme.categoryColor(index: index)
                        )
                    }
                    if summary.uncategorizedSpent > 0 {
                        HStack {
                            Circle().fill(Theme.otherColor).frame(width: 10, height: 10)
                            Text("項目なし")
                            Spacer()
                            Text(summary.uncategorizedSpent.yenText)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("項目ごと（人ごと）")
                } footer: {
                    Text("バーの枠が目標、色の帯が使った額です。薄い部分が残りで、月末まで残れば旅行資金になります。")
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

    /// ドーナツ型グラフの切れ。項目の色は「設定」の並び順で決まります。
    private func donutSlices(_ summary: MonthlySummary) -> [DonutSlice] {
        var slices = summary.categories.enumerated().compactMap { index, item -> DonutSlice? in
            guard item.spent > 0 else { return nil }
            return DonutSlice(
                id: item.id.uuidString,
                name: item.name,
                amount: item.spent,
                color: Theme.categoryColor(index: index)
            )
        }
        if summary.uncategorizedSpent > 0 {
            slices.append(DonutSlice(id: "none", name: "項目なし", amount: summary.uncategorizedSpent, color: Theme.otherColor))
        }
        return slices
    }
}

// 画面上部の、グラデーションの大きなカードです。今月の残りと、今日までの旅行資金を出します。
private struct HeroCard: View {
    let summary: MonthlySummary

    /// 表示のときに、数字が0から増えていくアニメーション用
    @State private var appeared = false

    private var spentRatio: CGFloat {
        guard summary.totalTarget > 0 else { return 0 }
        return min(CGFloat(summary.totalSpent) / CGFloat(summary.totalTarget), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.totalRemaining >= 0 ? "今月の残り" : "今月の目標オーバー")
                    .font(.subheadline)
                    .opacity(0.85)
                Text((appeared ? abs(summary.totalRemaining) : 0).yenText)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .monospacedDigit()
            }

            // 目標の合計のうち、使った割合を白いバーで表します
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule()
                        .fill(summary.totalRemaining >= 0 ? Color.white : Color.orange)
                        .frame(width: geometry.size.width * (appeared ? spentRatio : 0))
                }
            }
            .frame(height: 8)

            HStack {
                HeroValue(title: "目標の合計", value: summary.totalTarget)
                Spacer()
                HeroValue(title: "使った額", value: summary.totalSpent)
            }

            HStack(spacing: 8) {
                Image(systemName: "airplane")
                    .font(.headline)
                    .rotationEffect(.degrees(appeared ? -20 : 0))
                    .offset(x: appeared ? 0 : -16)
                VStack(alignment: .leading, spacing: 0) {
                    Text("今日までの旅行資金")
                        .font(.caption)
                        .opacity(0.85)
                    Text((appeared ? summary.projectedTravelFund : 0).signedYenText)
                        .font(.headline)
                        .contentTransition(.numericText())
                        .monospacedDigit()
                }
                Spacer()
                if summary.extraIncome > 0 {
                    Text("臨時収入 \(summary.extraIncome.signedYenText) を含む")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2), in: Capsule())
                }
            }
            .padding(12)
            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
        }
        .foregroundStyle(.white)
        .padding(20)
        .onAppear {
            withAnimation(.spring(duration: 1.0)) { appeared = true }
        }
    }
}

private struct HeroValue: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .opacity(0.85)
            Text(value.yenText)
                .font(.headline)
                .monospacedDigit()
        }
    }
}

// 1日あたりの目標と、今日・今日までの使った額です。
private struct DailyOverview: View {
    let summary: MonthlySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 16) {
                // 今日の支出が、1日あたりの目標のどれくらいかを輪で表します
                RingProgress(
                    progress: summary.dailyTarget > 0
                        ? Double(summary.todaySpent) / Double(summary.dailyTarget)
                        : 0,
                    lineWidth: 8,
                    gradient: .travel
                ) {
                    VStack(spacing: 0) {
                        Text("今日")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(percentText)
                            .font(.caption.bold())
                    }
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text("今日の支出 \(summary.todaySpent.yenText)")
                        .font(.headline)
                    Text("1日あたりの目標 \(summary.dailyTarget.yenText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    DifferenceText(difference: summary.dailyTarget - summary.todaySpent)
                        .font(.subheadline)
                }
            }

            Divider()

            HStack {
                Text("今日（\(summary.daily.today)日）までの目標 \(summary.targetUntilToday.yenText)")
                Spacer()
                DifferenceText(difference: summary.targetUntilToday - summary.totalSpent)
            }
            .font(.caption)
            Text("目標の合計 \(summary.totalTarget.yenText) ÷ \(summary.daily.daysInMonth)日")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var percentText: String {
        guard summary.dailyTarget > 0 else { return "-" }
        return "\(Int((Double(summary.todaySpent) / Double(summary.dailyTarget) * 100).rounded()))%"
    }
}

// メンバー1人ぶんの、今月の目標・使った額・目標との差です。
private struct MemberRow: View {
    let member: MemberSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(member.name)
                    .font(.headline)
                Spacer()
                DifferenceText(difference: member.difference)
            }
            BudgetBar(spent: member.spent, target: member.target, color: Theme.positive)
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
            Label("\((-difference).yenText)オーバー", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}

// 項目1つぶんの行です。人ごとに、目標と使った額のバーと、旅行資金になりそうな差額を出します。
private struct CategoryProgressRow: View {
    let item: CategorySummary
    let daily: DailyBudget
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(item.name)
                    .font(.headline)
            }

            ForEach(item.members) { member in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name)
                            .font(.subheadline)
                        Spacer()
                        DifferenceText(difference: member.difference)
                            .font(.subheadline)
                    }

                    BudgetBar(spent: member.spent, target: member.target, color: color)

                    HStack {
                        Text("使った額 \(member.spent.yenText) ／ 目標 \(member.target.yenText)（1日 \(daily.perDay(member.target).yenText)）")
                        Spacer()
                        if member.difference > 0 {
                            Label(member.difference.signedYenText, systemImage: "airplane")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HomeView()
        .environment(PreviewData.store)
}
