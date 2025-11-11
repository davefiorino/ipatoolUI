import SwiftUI

struct VersionMetadataView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: VersionMetadataViewModel

    init(viewModel: VersionMetadataViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox("Lookup") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("External Version ID", text: $viewModel.externalVersionID)
                        .textFieldStyle(.roundedBorder)
                    TextField("App ID", text: $viewModel.appIDString)
                        .textFieldStyle(.roundedBorder)
                    TextField("Bundle Identifier", text: $viewModel.bundleIdentifier)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Spacer()
                        Button(action: fetch) {
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Label("Fetch Metadata", systemImage: "info.circle")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }

            if let details = viewModel.details {
                GroupBox("Result") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version: \(details.displayVersion ?? "Unknown")")
                        Text("External ID: \(details.externalVersionID ?? viewModel.externalVersionID)")
                            .font(.callout)
                        if let date = details.releaseDate {
                            Text("Released: \(date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.callout)
                        }
                    }
                    .padding()
                }
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

    private func fetch() {
        viewModel.fetch(using: appState.environmentSnapshot())
    }
}

struct VersionMetadataView_Previews: PreviewProvider {
    static var previews: some View {
        let appState = AppState()
        VersionMetadataView(viewModel: appState.versionMetadataViewModel)
            .environmentObject(appState)
    }
}
