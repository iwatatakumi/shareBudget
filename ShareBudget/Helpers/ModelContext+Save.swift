import SwiftData

extension ModelContext {
    /// 変更をすぐに保存します。
    /// 保存すると、ほかのタブの画面（ホームなど）にも変更がすぐ反映されます。
    func saveChanges() {
        do {
            try save()
        } catch {
            print("保存に失敗しました: \(error)")
        }
    }
}
