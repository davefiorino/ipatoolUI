import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: AuthViewModel

    init(viewModel: AuthViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Form {
            Section("Apple ID") {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                SecureField("Password", text: $viewModel.password)
                TextField("2FA Code (optional)", text: $viewModel.authCode)
                    .textFieldStyle(.roundedBorder)
            }

            Section("Actions") {
                HStack {
                    Button("Sign In", action: signIn)
                        .disabled(viewModel.isWorking)
                    Button("Account Info", action: fetchInfo)
                        .disabled(viewModel.isWorking)
                    Button("Revoke", action: revoke)
                        .disabled(viewModel.isWorking)
                }
            }

            Section("Status") {
                Text(viewModel.statusMessage)
                    .font(.callout)
                if viewModel.isWorking {
                    ProgressView()
                }
                if let error = viewModel.activeError {
                    switch error {
                    case .executableNotFound:
                        InstallIpatoolHintView()
                    default:
                        Text(error.localizedDescription)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            viewModel.bootstrap(using: appState.environmentSnapshot())
        }
    }

    private func signIn() {
        viewModel.login(using: appState.environmentSnapshot())
    }

    private func fetchInfo() {
        viewModel.fetchInfo(using: appState.environmentSnapshot())
    }

    private func revoke() {
        viewModel.revoke(using: appState.environmentSnapshot())
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState()
        AuthView(viewModel: appState.authViewModel)
            .environmentObject(appState)
    }
}
