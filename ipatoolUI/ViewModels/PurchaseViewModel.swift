import Foundation

@MainActor
final class PurchaseViewModel: ObservableObject {
    @Published var bundleIdentifier: String = ""
    @Published var statusMessage: String?
    @Published var isProcessing: Bool = false
    @Published var activeError: IpatoolError?

    func purchase(using environment: CommandEnvironment) {
        let bundleID = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bundleID.isEmpty else {
            activeError = .invalidInput("Bundle identifier is required.")
            return
        }

        isProcessing = true
        activeError = nil
        statusMessage = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await environment.service.execute(subcommand: ["purchase", "--bundle-identifier", bundleID], environment: environment)
                let payload: StatusLogEvent = try environment.service.decodeEvent(StatusLogEvent.self, from: result.stdout)
                if payload.success == true {
                    self.statusMessage = "License obtained for \(bundleID)."
                } else {
                    self.statusMessage = "Command finished."
                }
            } catch let error as IpatoolError {
                self.activeError = error
            } catch {
                self.activeError = .commandFailed(error.localizedDescription)
            }

            self.isProcessing = false
        }
    }
}
