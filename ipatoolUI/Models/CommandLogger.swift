import Foundation

struct CommandLogEntry: Identifiable {
    let id = UUID()
    let executablePath: String
    let arguments: [String]
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let timestamp: Date
    let duration: TimeInterval

    var success: Bool { exitCode == 0 }

    var commandLine: String {
        ([executablePath] + arguments).joined(separator: " ")
    }
}

@MainActor
final class CommandLogger: ObservableObject {
    @Published private(set) var entries: [CommandLogEntry] = []

    func append(_ entry: CommandLogEntry) {
        entries.insert(entry, at: 0)
    }

    func clear() {
        entries.removeAll()
    }
}
