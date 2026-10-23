import SwiftUI

// メールアドレスとパスワードで、ログインまたは新規登録する画面です。
struct AuthView: View {
    @Environment(BudgetStore.self) private var store

    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "ログイン"
        case signUp = "新規登録"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .signUp
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var notice: String?

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !isWorking
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField("メールアドレス", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("パスワード（6文字以上）", text: $password)
                        .textContentType(mode == .signUp ? .newPassword : .password)
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isWorking {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(mode.rawValue)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!canSubmit)
                } footer: {
                    if let notice {
                        Text(notice)
                    } else {
                        Text("ルームメイトも、それぞれ自分のメールアドレスで登録します。")
                    }
                }
            }
            .navigationTitle("シェアバジェット")
        }
    }

    private func submit() async {
        isWorking = true
        defer { isWorking = false }
        notice = nil

        switch mode {
        case .signIn:
            await store.signIn(email: email, password: password)
        case .signUp:
            let signedIn = await store.signUp(email: email, password: password)
            if !signedIn && store.errorMessage == nil {
                notice = "確認メールを送りました。メールのリンクを開いてから「ログイン」してください。"
                mode = .signIn
            }
        }
    }
}

#Preview {
    AuthView()
        .environment(PreviewData.store)
}
