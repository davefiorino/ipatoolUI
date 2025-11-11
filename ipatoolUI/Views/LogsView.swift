import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Commands")
                    .font(.title3)
                Spacer()
                Button("Clear", action: clear)
                    .disabled(appState.commandLogger.entries.isEmpty)
            }

            List(appState.commandLogger.entries) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.commandLine)
                            .font(.headline)
                        Spacer()
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(entry.success ? "Success" : "Failure (code \(entry.exitCode))")
                        .foregroundStyle(entry.success ? .green : .red)
                    if !entry.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        DisclosureGroup("Output") {
                            ScrollView {
                                Text(entry.stdout)
                                    .font(.system(.footnote, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 150)
                        }
                    }
                    if !entry.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        DisclosureGroup("Errors") {
                            ScrollView {
                                Text(entry.stderr)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 150)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }

    private func clear() {
        appState.commandLogger.clear()
    }
}
