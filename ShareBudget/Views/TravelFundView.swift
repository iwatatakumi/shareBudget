import SwiftUI

// 旅行資金タブです。貯まった旅行資金の合計と月ごとの記録、
// それに合わせた旅行先の候補（アプリに入っているデータ）を表示します。
struct TravelFundView: View {
    @Environment(BudgetStore.self) private var store
    /// true のとき、いまの旅行資金で行ける候補だけを表示します
    @State private var showsAffordableOnly = false

    var body: some View {
        let fund = TravelFund(store: store)
        let people = max(store.members.count, 1)
        let ideas = TravelIdea.samples
            .filter { !showsAffordableOnly || $0.costPerPerson * people <= fund.total }
            .sorted { $0.costPerPerson < $1.costPerPerson }

        NavigationStack {
            List {
                Section {
                    FundTotalView(total: fund.total)
                }

                Section {
                    ForEach(fund.months) { month in
                        MonthlyFundRow(month: month)
                    }
                } header: {
                    Text("月ごとの記録")
                } footer: {
                    Text("終わった月は「1か月の目標 − 使った額」、今月は「今日までの目標 − 使った額」です。過去の月も、いまの目標金額で計算しています。")
                }

                Section {
                    Toggle("いまの旅行資金で行ける所だけ", isOn: $showsAffordableOnly)
                    if ideas.isEmpty {
                        Text("いまの旅行資金で行ける候補はまだありません。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(ideas) { idea in
                        TravelIdeaRow(idea: idea, people: people, fund: fund.total)
                    }
                } header: {
                    Text("旅行先の候補（\(people)人で行く場合）")
                } footer: {
                    Text("東京発・1人あたりのおおまかな目安です。実際の費用は時期や予約のしかたで変わるので、「最新の航空券の値段を調べる」で確かめてください。")
                }
            }
            .navigationTitle("旅行資金")
            .refreshable {
                await store.reload()
            }
        }
    }
}

// 貯まった旅行資金の合計です。
private struct FundTotalView: View {
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("貯まった旅行資金")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(total.signedYenText)
                .font(.largeTitle.bold())
                .foregroundStyle(total >= 0 ? Color.accentColor : Color.red)
        }
        .padding(.vertical, 4)
    }
}

// 1か月ぶんの旅行資金の行です。
private struct MonthlyFundRow: View {
    let month: MonthlyFund

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(month.isCurrent ? "\(month.title)（今日まで）" : month.title)
                Spacer()
                Text(month.fund.signedYenText)
                    .bold()
                    .foregroundStyle(month.fund >= 0 ? Color.primary : Color.red)
            }
            Text("目標 \(month.target.yenText) ／ 使った額 \(month.spent.yenText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// 旅行先の候補1つぶんの行です。
private struct TravelIdeaRow: View {
    let idea: TravelIdea
    let people: Int
    let fund: Int

    private var totalCost: Int { idea.costPerPerson * people }
    private var shortage: Int { totalCost - fund }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(idea.city)
                    .font(.headline)
                Text(idea.country)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(idea.days)日間")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Label(idea.route, systemImage: "map")
                .font(.subheadline)

            if !idea.highlights.isEmpty {
                Text(idea.highlights.joined(separator: "・"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("1人 約\(idea.costPerPerson.yenText)（\(idea.costNote)）")
                .font(.caption)
                .foregroundStyle(.secondary)

            // バーの長さ = 貯まった旅行資金 ÷ 必要な費用
            ProgressView(
                value: Double(min(max(fund, 0), max(totalCost, 1))),
                total: Double(max(totalCost, 1))
            )

            HStack {
                Text("\(people)人で約\(totalCost.yenText)")
                Spacer()
                if shortage <= 0 {
                    Text("いまの旅行資金で行けます")
                        .foregroundStyle(Color.accentColor)
                        .bold()
                } else {
                    Text("あと\(shortage.yenText)")
                }
            }
            .font(.subheadline)

            // Safari でGoogleフライトを開きます（無料で、最新の値段を調べられます）
            if let url = idea.flightSearchURL {
                Link(destination: url) {
                    Label("最新の航空券の値段を調べる", systemImage: "safari")
                }
                .font(.subheadline)
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TravelFundView()
        .environment(PreviewData.store)
}
