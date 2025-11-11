import SwiftUI

struct MainView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            List(Feature.allCases, selection: $appState.selectedFeature) { feature in
                Label(feature.title, systemImage: feature.icon)
                    .tag(feature)
            }
            .frame(minWidth: 220)
            .navigationTitle("ipatool UI")
        } detail: {
            contentView(for: appState.selectedFeature)
                .frame(minWidth: 520, minHeight: 520)
                .padding()
        }
    }

    @ViewBuilder
    private func contentView(for feature: Feature) -> some View {
        switch feature {
        case .auth:
            AuthView(viewModel: appState.authViewModel)
        case .search:
            SearchView(viewModel: appState.searchViewModel)
        case .purchase:
            PurchaseView()
        case .listVersions:
            ListVersionsView(viewModel: appState.listVersionsViewModel)
        case .download:
            DownloadView(viewModel: appState.downloadViewModel)
        case .metadata:
            VersionMetadataView(viewModel: appState.versionMetadataViewModel)
        case .logs:
            LogsView()
        case .settings:
            SettingsView()
        case .about:
            AboutView()
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(AppState())
    }
}
