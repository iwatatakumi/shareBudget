import SwiftUI

// 旅行資金タブです。貯まった旅行資金の合計と月ごとの記録、
// それに合わせた旅行先の候補（アプリに入っているデータ）を表示します。
struct TravelFundView: View {
    @Environment(BudgetStore.self) private var store
    /// true のとき、いまの旅行資金で行ける候補だけを表示します
    @State private var showsAffordableOnly = false
    @State private var showsIncomeForm = false
    // 削除してよいか確認中の臨時収入
    @State private var incomeToDelete: Income?

    var body: some View {
        let fund = TravelFund(store: store)
        let people = max(store.members.count, 1)
        let sortedIdeas = TravelIdea.samples.sorted { $0.costPerPerson < $1.costPerPerson }
        let ideas = sortedIdeas.filter { !showsAffordableOnly || $0.costPerPerson * people <= fund.total }
        // 次の目標: まだ届いていない候補のうち、一番安いもの
        let nextGoal = sortedIdeas.first { $0.costPerPerson * people > fund.total }

        NavigationStack {
            List {
                Section {
                    FundHeroCard(total: fund.total, nextGoal: nextGoal, people: people)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(GlossyCardBackground(gradient: Theme.travelGradient))
                }

                // ここから下の行は、すりガラスのような背景にします
                Group {
                    incomeSection

                    Section {
                        MonthlyFundChart(months: fund.months)
                        ForEach(fund.months) { month in
                            MonthlyFundRow(month: month)
                        }
                    } header: {
                        Text("月ごとの記録")
                    } footer: {
                        Text("終わった月は「1か月の目標 − 使った額 ＋ 臨時収入」、今月は「今日までの目標 − 使った額 ＋ 臨時収入」です。過去の月も、いまの目標金額で計算しています。")
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
                .listRowBackground(Theme.glassRow)
            }
            .luxuryBackground()
            .navigationTitle("旅行資金")
            .refreshable {
                await store.reload()
            }
            .sheet(isPresented: $showsIncomeForm) {
                IncomeFormView()
            }
            .confirmationDialog(
                "この臨時収入を削除しますか？",
                isPresented: Binding(
                    get: { incomeToDelete != nil },
                    set: { if !$0 { incomeToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: incomeToDelete
            ) { income in
                Button("\(income.amount.yenText)を削除", role: .destructive) {
                    Task { await store.deleteIncome(income) }
                    incomeToDelete = nil
                }
            } message: { _ in
                Text("旅行資金からも、その分が引かれます。")
            }
        }
    }

    // 臨時収入の一覧と、追加ボタンです。
    private var incomeSection: some View {
        Section {
            Button {
                showsIncomeForm = true
            } label: {
                Label("臨時収入を追加", systemImage: "plus.circle")
            }
            ForEach(store.incomes) { income in
                IncomeRow(income: income, memberName: store.memberName(income.createdBy))
            }
            .onDelete { offsets in
                incomeToDelete = offsets.first.map { store.incomes[$0] }
            }
        } header: {
            Text("臨時収入")
        } footer: {
            Text("ボーナスやお祝いなど、入力した金額がそのまま旅行資金に足されます。左にスワイプすると削除できます。")
        }
    }
}

// 臨時収入1件ぶんの行です。
private struct IncomeRow: View {
    let income: Income
    let memberName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(income.memo.isEmpty ? "臨時収入" : income.memo)
                Text("\(income.receivedOn.replacingOccurrences(of: "-", with: "/"))・\(memberName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(income.amount.signedYenText)
                .bold()
                .foregroundStyle(Theme.goldGradient)
        }
    }
}

// 画面上部の、グラデーションの大きなカードです。
// 貯まった旅行資金の合計と、次の目標（まだ届いていない一番安い旅行先）までの進み具合を輪で出します。
private struct FundHeroCard: View {
    let total: Int
    let nextGoal: TravelIdea?
    let people: Int

    @State private var appeared = false
    /// 飛行機がふわふわ浮かぶアニメーション用
    @State private var floating = false

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("貯まった旅行資金")
                    .font(.subheadline)
                    .opacity(0.85)
                Text((appeared ? total : 0).signedYenText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.goldGradient)
                    .shadow(color: Theme.gold.opacity(0.5), radius: 8)
                    .contentTransition(.numericText())
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let nextGoal {
                    let cost = nextGoal.costPerPerson * people
                    Text("次の目標: \(nextGoal.city)（\(people)人で約\(cost.yenText)）")
                        .font(.caption)
                        .opacity(0.9)
                    Text("あと\(max(cost - total, 0).yenText)")
                        .font(.headline)
                } else {
                    Text("候補の旅行先すべてに行けます！")
                        .font(.headline)
                }
            }

            Spacer(minLength: 0)

            RingProgress(
                progress: goalProgress,
                lineWidth: 10,
                gradient: Theme.goldRing
            ) {
                Image(systemName: "airplane")
                    .font(.title2)
                    .foregroundStyle(Theme.goldGradient)
                    .offset(y: floating ? -4 : 4)
            }
            .frame(width: 84, height: 84)
        }
        .foregroundStyle(.white)
        .padding(20)
        .onAppear {
            withAnimation(.spring(duration: 1.0)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { floating = true }
        }
    }

    /// 次の目標までの進み具合（0〜1）。すべて行けるときは満タン。
    private var goalProgress: Double {
        guard let nextGoal else { return 1 }
        let cost = Double(nextGoal.costPerPerson * people)
        return cost > 0 ? max(Double(total), 0) / cost : 0
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
            Text(month.income > 0
                ? "目標 \(month.target.yenText) ／ 使った額 \(month.spent.yenText) ／ 臨時収入 \(month.income.yenText)"
                : "目標 \(month.target.yenText) ／ 使った額 \(month.spent.yenText)")
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

    private var percentText: String {
        guard totalCost > 0 else { return "-" }
        return "\(min(Int((max(Double(fund), 0) / Double(totalCost) * 100).rounded()), 999))%"
    }

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

            HStack(spacing: 12) {
                // 輪 = 貯まった旅行資金 ÷ 必要な費用
                RingProgress(
                    progress: totalCost > 0 ? max(Double(fund), 0) / Double(totalCost) : 0,
                    lineWidth: 6,
                    gradient: .travel
                ) {
                    Text(percentText)
                        .font(.caption2.bold())
                        .monospacedDigit()
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(people)人で約\(totalCost.yenText)")
                        .font(.subheadline)
                    if shortage <= 0 {
                        Label("いまの旅行資金で行けます", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.positive)
                    } else {
                        Text("あと\(shortage.yenText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

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
