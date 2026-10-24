import Foundation

// Supabase（2人のデータを保存するサービス）につなぐための設定です。
// Supabaseの管理画面「Project Settings」→「API Keys」に出ている値に書きかえてください。
//
// publishable key（または anon public キー）は、アプリに入れて公開しても大丈夫なキーです。
// 「secret」「service_role」と書かれたキーは、ここに絶対に入れないでください。
enum SupabaseConfig {
    static let url = "https://iyarbsxybxurfxvrzipt.supabase.co"
    static let publishableKey = "sb_publishable_8oJI3AwOdXbLJJGM_ItE1g_s0IV42Mb"

    /// 上の2つが書きかえられているかどうか
    static var isConfigured: Bool {
        !url.contains("YOUR-PROJECT") && !publishableKey.contains("YOUR-PUBLISHABLE-KEY")
    }
}
