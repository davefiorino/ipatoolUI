import Foundation

struct CommandExecutionResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let duration: TimeInterval
}

final class IpatoolService {
    private let decoder: JSONDecoder

    init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    static let defaultExecutablePath: String? = {
        let candidates = [
            "/opt/homebrew/bin/ipatool",
            "/usr/local/bin/ipatool",
            "/usr/bin/ipatool",
            "/opt/local/bin/ipatool"
        ]
        let fileManager = FileManager.default
        for path in candidates where fileManager.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }()

    static func autoDetectExecutablePath() -> String? {
        if let preset = defaultExecutablePath {
            return preset
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ipatool"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return path.isEmpty ? nil : path
    }

    func execute(subcommand: [String], environment: CommandEnvironment) async throws -> CommandExecutionResult {
        let path = resolveExecutablePath(from: environment.preferences)
        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw IpatoolError.executableNotFound
        }

        let arguments = buildArguments(using: environment.preferences, subcommand: subcommand)
        let startDate = Date()
        let result = try await runProcess(executablePath: path, arguments: arguments)
        let duration = Date().timeIntervalSince(startDate)
        let finalResult = CommandExecutionResult(
            stdout: result.stdout,
            stderr: result.stderr,
            exitCode: result.exitCode,
            duration: duration
        )

        let sanitizedArgs = sanitize(arguments: arguments)

        await MainActor.run {
            environment.logger.append(
                CommandLogEntry(
                    executablePath: path,
                    arguments: sanitizedArgs,
                    stdout: finalResult.stdout,
                    stderr: finalResult.stderr,
                    exitCode: finalResult.exitCode,
                    timestamp: Date(),
                    duration: finalResult.duration
                )
            )
        }

        if finalResult.exitCode != 0 {
            throw IpatoolError.commandFailed(finalResult.stderr.isEmpty ? finalResult.stdout : finalResult.stderr)
        }

        return finalResult
    }

    func decodeEvent<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.first == "{" else { continue }
            guard let data = trimmed.data(using: .utf8) else { continue }
            if let decoded = try? decoder.decode(T.self, from: data) {
                return decoded
            }
        }
        throw IpatoolError.decodingFailed
    }

    private func resolveExecutablePath(from preferences: Preferences) -> String {
        if !preferences.ipatoolPath.isEmpty {
            return preferences.ipatoolPath
        }
        return IpatoolService.defaultExecutablePath ?? ""
    }

    private func buildArguments(using preferences: Preferences, subcommand: [String]) -> [String] {
        var args: [String] = []
        args.append(contentsOf: ["--format", preferences.outputFormat.rawValue])
        if preferences.nonInteractive {
            args.append("--non-interactive")
        }
        if preferences.verboseLogs {
            args.append("--verbose")
        }
        if !preferences.keychainPassphrase.trimmingCharacters(in: .whitespaces).isEmpty {
            args.append(contentsOf: ["--keychain-passphrase", preferences.keychainPassphrase])
        }
        args.append(contentsOf: subcommand)
        return args
    }

    private func sanitize(arguments: [String]) -> [String] {
        var sanitized = arguments
        let sensitiveFlags: Set<String> = ["--password", "--auth-code", "--keychain-passphrase"]
        var index = 0
        while index < sanitized.count {
            let value = sanitized[index]
            if sensitiveFlags.contains(value), index + 1 < sanitized.count {
                sanitized[index + 1] = "••••••"
                index += 2
            } else {
                index += 1
            }
        }
        return sanitized
    }

    private func runProcess(executablePath: String, arguments: [String]) async throws -> CommandExecutionResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                let result = CommandExecutionResult(
                    stdout: stdout,
                    stderr: stderr,
                    exitCode: process.terminationStatus,
                    duration: 0
                )
                continuation.resume(returning: result)
            }
        }
    }
}
