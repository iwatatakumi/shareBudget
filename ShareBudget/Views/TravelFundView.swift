import SwiftUI

// 旅行資金タブです。貯まった旅行資金の合計と月ごとの記録、
// それに合わせた旅行先の候補（AIが探したもの、またはアプリに入っている参考の候補）を表示します。
struct TravelFundView: View {
    @Environment(BudgetStore.self) private var store
    @State private var isSearching = false

    var body: some View {
        let fund = TravelFund(store: store)
        let people = max(store.members.count, 1)

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
                    searchButton(fund: fund.total)
                    // AIの結果に同じ名前の候補があっても困らないように、並び順で区別します。
                    ForEach(Array(ideas.enumerated()), id: \.offset) { _, idea in
                        TravelIdeaRow(idea: idea, people: people, fund: fund.total)
                    }
                } header: {
                    Text("旅行先の候補（\(people)人で行く場合）")
                } footer: {
                    Text(ideasFooter)
                }
            }
            .navigationTitle("旅行資金")
            .refreshable {
                await store.reload()
            }
            .overlay {
                if isSearching {
                    ProgressView("AIが旅行先を探しています…\n（1分ほどかかることがあります）")
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    /// 表示する候補。AIで探していれば、その結果を使います。
    private var ideas: [TravelIdea] {
        if let ideas = store.travelSuggestions?.ideas, !ideas.isEmpty {
            return ideas
        }
        return TravelIdea.samples
    }

    private var ideasFooter: String {
        if let suggestions = store.travelSuggestions, !suggestions.ideas.isEmpty {
            let date = suggestions.createdDate?.formatted(date: .abbreviated, time: .shortened) ?? ""
            return "\(date)にAIがネットで調べた、日本発の費用の目安です。実際の費用は時期や予約のしかたで変わります。"
        }
        return "アプリに入っている参考の候補です（日本発・おおまかな目安）。「AIで旅行先を探す」を押すと、いまの旅行資金に合わせて最新の情報で探します。"
    }

    private func searchButton(fund: Int) -> some View {
        Button {
            Task {
                isSearching = true
                _ = await store.searchTravelIdeas(fund: fund)
                isSearching = false
            }
        } label: {
            Label("AIで旅行先を探す", systemImage: "sparkles")
        }
        .disabled(isSearching)
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
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TravelFundView()
        .environment(PreviewData.store)
}
