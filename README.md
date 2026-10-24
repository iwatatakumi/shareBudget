# シェアバジェット

ルームメイトと2人で共有できる、iPhone向けの家計簿アプリです。
項目ごとに毎月の目標金額を決め、使わずに済んだ差分を「旅行資金」として貯めていきます。

## いまできていること

- 画面下の5つのタブ（ホーム・入力・一覧・旅行資金・設定）の切り替え
- 「入力」タブで支出（金額・項目・日付・メモ）を保存する
- 「一覧」タブで今月の支出と合計を見る。行を押すと修正、左にスワイプすると削除
- 「設定」タブで項目の追加・名前の変更・削除・並び替えと、1か月の目標金額の設定
- 「ホーム」タブで今月の残り、項目ごとの使った割合、今日までの旅行資金（各項目の今日までの目標と使った額の差の合計）を見る
- メールアドレスは不要。家計簿を作った人（管理者）が決めたパスワードと家計簿IDを教えて、ルームメイトと同じ家計簿を使う
- 支出ごとの配分（均等・自分だけ・金額を指定）と、人ごと・項目ごとの目標金額
- 「ホーム」でメンバーごと・項目ごとの「使った額 ／ 目標 ／ 目標との差」を見る
- 月の目標金額をその月の日数で日割りした「1日あたりの目標」と、今日・今日までの使った額との差を見る
- データはSupabase（PostgreSQL）に保存され、2人で共有されます
- 旅行資金の画面はまだ準備中です

## Macで動かす方法

1. Xcodeを開き、最初の画面で「Clone Git Repository...」を選びます。
   （最初の画面が出ない場合は、メニューの「Integrate」→「Clone...」）
2. `https://github.com/iwatatakumi/shareBudget` を入力して「Clone」を押し、保存場所を選びます。
3. 開いたら、画面上部の真ん中あたりにある実行先を「iPhone 16」などのシミュレーター（画面上の仮想iPhone）にします。
4. 左上の ▶（Run）ボタンを押すと、シミュレーターでアプリが起動します。

自分のiPhoneで動かすときは、左の一覧で一番上の「ShareBudget」→「Signing & Capabilities」を開き、「Team」に自分のApple IDを選んでください。

## Supabaseの準備（最初に1回だけ）

1. [supabase.com](https://supabase.com) でプロジェクトを作ります（Region: Northeast Asia (Tokyo)、プラン: Free）。
2. 「Authentication」→「Sign In / Providers」で「Allow anonymous sign-ins」をオンにして「Save changes」を押します。
   （メールアドレスなしで、端末ごとに名前のない利用者を自動で作る設定です）
3. 「SQL Editor」を開き、このリポジトリの `supabase/schema.sql` の中身をすべて貼り付けて「Run」を押します。
4. 「Project Settings」→「API Keys」の Project URL と publishable key（または anon public キー）を、
   `ShareBudget/Supabase/SupabaseConfig.swift` に書きます。

## 使っている技術

- Swift / SwiftUI（iPhoneアプリの言語と、画面を作る仕組み）
- PostgreSQL（Supabase）（2人のデータの共有）。Swiftからは [supabase-swift](https://github.com/supabase/supabase-swift) で使います

## 必要な環境

- Xcode 16 以降
- iOS 17 以降
