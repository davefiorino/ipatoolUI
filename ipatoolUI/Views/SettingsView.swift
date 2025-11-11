import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var detectionMessage: String?

    var body: some View {
        Form {
            Section("ipatool Binary") {
                HStack {
                    TextField("Path to ipatool", text: binding(\.ipatoolPath))
                        .textFieldStyle(.roundedBorder)
                    Button("Browse…", action: browseForExecutable)
                    Button("Auto-Detect", action: autoDetect)
                }
                if let message = detectionMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Behavior") {
                Toggle("Non-interactive", isOn: binding(\.nonInteractive))
                Toggle("Verbose Logs", isOn: binding(\.verboseLogs))
                Picker("Output Format", selection: binding(\.outputFormat)) {
                    ForEach(Preferences.OutputFormat.allCases) { format in
                        Text(format.rawValue.uppercased()).tag(format)
                    }
                }
                SecureField("Keychain Passphrase", text: binding(\.keychainPassphrase))
                    .textFieldStyle(.roundedBorder)
            }
        }
        .formStyle(.grouped)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<Preferences, Value>) -> Binding<Value> {
        Binding(
            get: { appState.preferences[keyPath: keyPath] },
            set: { appState.preferences[keyPath: keyPath] = $0 }
        )
    }

    private func autoDetect() {
        if let detected = IpatoolService.autoDetectExecutablePath() {
            appState.preferences.ipatoolPath = detected
            detectionMessage = "Detected at \(detected)."
        } else {
            detectionMessage = "Unable to locate ipatool. Install it via Homebrew first."
        }
    }

    private func browseForExecutable() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            appState.preferences.ipatoolPath = url.path
            detectionMessage = "Using \(url.path)"
        }
        #endif
    }
}
