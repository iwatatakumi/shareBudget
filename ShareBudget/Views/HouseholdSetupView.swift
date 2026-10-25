import SwiftUI

// はじめてアプリを開いたときに、家計簿を新しく作るか、ルームメイトの家計簿に参加する画面です。
struct HouseholdSetupView: View {
    @Environment(BudgetStore.self) private var store

    @State private var displayName = ""
    @State private var newPassword = ""
    @State private var inviteCode = ""
    @State private var joinPassword = ""
    @State private var isWorking = false

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            LuxuryForm {
                Section {
                    TextField("例: たくみ", text: $displayName)
                } header: {
                    Text("あなたの名前")
                } footer: {
                    Text("家計簿の中で、ルームメイトに表示される名前です。")
                }

                Section {
                    SecureField("参加用パスワード（4文字以上）", text: $newPassword)
                    Button("新しく家計簿を作る") {
                        Task {
                            isWorking = true
                            await store.createHousehold(displayName: trimmedName, password: newPassword)
                            isWorking = false
                        }
                    }
                    .disabled(trimmedName.isEmpty || newPassword.count < 4 || isWorking)
                } header: {
                    Text("はじめて使う人（管理者）")
                } footer: {
                    Text("作ったあと「設定」タブに出る家計簿IDと、ここで決めたパスワードを、ルームメイトに教えてください。")
                }

                Section {
                    TextField("家計簿ID（6文字）", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    SecureField("パスワード", text: $joinPassword)
                    Button("この家計簿に参加する") {
                        Task {
                            isWorking = true
                            await store.joinHousehold(
                                inviteCode: inviteCode,
                                password: joinPassword,
                                displayName: trimmedName
                            )
                            isWorking = false
                        }
                    }
                    .disabled(trimmedName.isEmpty || inviteCode.count < 6 || joinPassword.isEmpty || isWorking)
                } header: {
                    Text("ルームメイトに誘われた人")
                } footer: {
                    Text("家計簿を作った人から、家計簿IDとパスワードを教えてもらってください。")
                }
            }
            .navigationTitle("家計簿の準備")
            .overlay {
                if isWorking {
                    ProgressView()
                }
            }
        }
    }
}

#Preview {
    HouseholdSetupView()
        .environment(PreviewData.store)
}
