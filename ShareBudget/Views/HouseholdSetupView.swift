import SwiftUI

// ログインのあと、家計簿を新しく作るか、ルームメイトの家計簿に参加する画面です。
struct HouseholdSetupView: View {
    @Environment(BudgetStore.self) private var store

    @State private var displayName = ""
    @State private var inviteCode = ""
    @State private var isWorking = false

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例: たくみ", text: $displayName)
                } header: {
                    Text("あなたの名前")
                } footer: {
                    Text("家計簿の中で、ルームメイトに表示される名前です。")
                }

                Section {
                    Button("新しく家計簿を作る") {
                        Task {
                            isWorking = true
                            await store.createHousehold(displayName: trimmedName)
                            isWorking = false
                        }
                    }
                    .disabled(trimmedName.isEmpty || isWorking)
                } header: {
                    Text("はじめて使う人")
                } footer: {
                    Text("作ったあと「設定」タブに出る招待コードを、ルームメイトに教えてください。")
                }

                Section {
                    TextField("招待コード（6文字）", text: $inviteCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button("この家計簿に参加する") {
                        Task {
                            isWorking = true
                            await store.joinHousehold(inviteCode: inviteCode, displayName: trimmedName)
                            isWorking = false
                        }
                    }
                    .disabled(trimmedName.isEmpty || inviteCode.count < 6 || isWorking)
                } header: {
                    Text("ルームメイトに招待された人")
                }

                Section {
                    Button("ログアウト", role: .destructive) {
                        Task { await store.signOut() }
                    }
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
