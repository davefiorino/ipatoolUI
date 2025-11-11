import SwiftUI

struct AboutView: View {
    private let repoURL = URL(string: "https://github.com/majd/ipatool")!

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("About ipatool UI")
                .font(.largeTitle)
                .bold()

            Text("ipatool UI wraps the open-source ipatool CLI to make App Store searches, downloads, and purchases easier on macOS.")
                .font(.body)

            VStack(alignment: .leading, spacing: 8) {
                Text("Credits")
                    .font(.headline)
                Text("All CLI functionality is provided by the ipatool project. Consider starring the repository or contributing fixes upstream.")
                Link("View ipatool on GitHub", destination: repoURL)
                    .font(.body.weight(.semibold))
            }

            Spacer()
        }
        .padding()
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
    }
}
