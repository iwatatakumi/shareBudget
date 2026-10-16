# シェアバジェット

ルームメイトと2人で共有できる、iPhone向けの家計簿アプリです。
項目ごとに毎月の目標金額を決め、使わずに済んだ差分を「旅行資金」として貯めていきます。

## いまできていること

- 画面下の5つのタブ（ホーム・入力・一覧・旅行資金・設定）の切り替え
- 各画面の中身はまだ準備中です（何が入る予定かを表示しています）

## Macで動かす方法

1. Xcodeを開き、最初の画面で「Clone Git Repository...」を選びます。
   （最初の画面が出ない場合は、メニューの「Integrate」→「Clone...」）
2. `https://github.com/iwatatakumi/shareBudget` を入力して「Clone」を押し、保存場所を選びます。
3. 開いたら、画面上部の真ん中あたりにある実行先を「iPhone 16」などのシミュレーター（画面上の仮想iPhone）にします。
4. 左上の ▶（Run）ボタンを押すと、シミュレーターでアプリが起動します。

自分のiPhoneで動かすときは、左の一覧で一番上の「ShareBudget」→「Signing & Capabilities」を開き、「Team」に自分のApple IDを選んでください。

## 使っている技術

- Swift / SwiftUI（iPhoneアプリの言語と、画面を作る仕組み）
- PostgreSQL（Supabase）（2人のデータの共有。これから追加します）

## 必要な環境

- Xcode 16 以降
- iOS 17 以降
