import SwiftUI

struct PurchaseView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = PurchaseViewModel()

    var body: some View {
        Form {
            Section("App") {
                TextField("Bundle Identifier", text: $viewModel.bundleIdentifier)
                    .textFieldStyle(.roundedBorder)
            }

            Section {
                Button(action: purchase) {
                    if viewModel.isProcessing {
                        ProgressView()
                    } else {
                        Label("Purchase License", systemImage: "checkmark.seal")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isProcessing)
            }

            if let status = viewModel.statusMessage {
                Section("Status") {
                    Text(status)
                        .font(.callout)
                }
            }

            if let error = viewModel.activeError {
                Section("Error") {
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
    }

    private func purchase() {
        viewModel.purchase(using: appState.environmentSnapshot())
    }
}
