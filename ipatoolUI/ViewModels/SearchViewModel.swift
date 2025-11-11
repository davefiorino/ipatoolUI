import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var term: String = ""
    @Published var limit: Double = 5
    @Published var results: [IpatoolApp] = []
    @Published var isSearching: Bool = false
    @Published var feedback: String?
    @Published var activeError: IpatoolError?
    @Published private(set) var artworkCache: [Int64: URL] = [:]
    @Published private(set) var purchasedKeys: Set<String> = []
    @Published private(set) var pendingPurchaseKeys: Set<String> = []

    private let purchaseSemaphore = AsyncSemaphore(limit: 4)

    func search(using environment: CommandEnvironment) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            activeError = .invalidInput("Enter a search term.")
            return
        }

        isSearching = true
        activeError = nil
        feedback = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                var arguments = ["search", trimmed]
                arguments.append(contentsOf: ["--limit", String(Int(self.limit))])
                let result = try await environment.service.execute(subcommand: arguments, environment: environment)
                let response: SearchLogEvent = try environment.service.decodeEvent(SearchLogEvent.self, from: result.stdout)
                self.results = response.apps ?? []
                self.feedback = "Fetched \(response.count ?? self.results.count) app(s)."
                self.scheduleArtworkFetch(for: self.results)
                self.refreshPurchaseStatus(for: self.results, environment: environment)
            } catch let error as IpatoolError {
                self.activeError = error
            } catch {
                self.activeError = .commandFailed(error.localizedDescription)
            }

            self.isSearching = false
        }
    }

    func purchase(bundleID: String?, environment: CommandEnvironment) {
        guard let bundleID = bundleID, !bundleID.isEmpty else {
            activeError = .invalidInput("App bundle identifier is missing.")
            return
        }

        feedback = nil
        activeError = nil

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await environment.service.execute(subcommand: ["purchase", "--bundle-identifier", bundleID], environment: environment)
                let payload: StatusLogEvent = try environment.service.decodeEvent(StatusLogEvent.self, from: result.stdout)
                if payload.success == true {
                    self.feedback = "Purchase succeeded for \(bundleID)."
                    let key = self.purchaseKey(forBundle: bundleID)
                    self.purchasedKeys.insert(key)
                } else {
                    self.feedback = "Command finished but success flag missing."
                }
            } catch let error as IpatoolError {
                self.activeError = error
            } catch {
                self.activeError = .commandFailed(error.localizedDescription)
            }
        }
    }

    func artworkURL(for app: IpatoolApp) -> URL? {
        if let direct = app.artworkURL {
            return direct
        }
        if let id = app.trackID {
            return artworkCache[id]
        }
        return nil
    }

    func isPurchased(app: IpatoolApp) -> Bool {
        if let bundle = app.bundleID {
            if purchasedKeys.contains(purchaseKey(forBundle: bundle)) {
                return true
            }
        }
        if let trackID = app.trackID {
            return purchasedKeys.contains(purchaseKey(forTrackID: trackID))
        }
        return false
    }

    func ensurePurchaseStatus(for app: IpatoolApp, environment: CommandEnvironment) async {
        await runPurchaseCheck(for: app, environment: environment)
    }

    func isCheckingPurchase(for app: IpatoolApp) -> Bool {
        if let bundle = app.bundleID,
           pendingPurchaseKeys.contains(purchaseKey(forBundle: bundle)) {
            return true
        }
        if let trackID = app.trackID,
           pendingPurchaseKeys.contains(purchaseKey(forTrackID: trackID)) {
            return true
        }
        return false
    }
}

private extension SearchViewModel {
    func scheduleArtworkFetch(for apps: [IpatoolApp]) {
        let missingIDs = apps
            .compactMap { $0.trackID }
            .filter { artworkCache[$0] == nil }
        guard !missingIDs.isEmpty else { return }

        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let map = try await LookupService.lookupArtwork(trackIDs: missingIDs)
                await MainActor.run {
                    for (id, url) in map {
                        self.artworkCache[id] = url
                    }
                }
            } catch {
                // Ignore failures; icons remain placeholders.
            }
        }
    }

    func refreshPurchaseStatus(for apps: [IpatoolApp], environment: CommandEnvironment) {
        Task { [weak self] in
            guard let self else { return }
            for app in apps {
                await self.runPurchaseCheck(for: app, environment: environment)
            }
        }
    }

    func runPurchaseCheck(for app: IpatoolApp, environment: CommandEnvironment) async {
        guard let key = purchaseKey(for: app) else { return }
        if purchasedKeys.contains(key) || pendingPurchaseKeys.contains(key) { return }
        pendingPurchaseKeys.insert(key)

        await purchaseSemaphore.wait()

        defer {
            pendingPurchaseKeys.remove(key)
            Task { await purchaseSemaphore.signal() }
        }

        let commands = listVersionsCommands(for: app)
        guard !commands.isEmpty else { return }

        var remainingRetries = 3

        commandLoop: for command in commands {
            var attempt = 0
            while attempt < 2 {
                do {
                    let result = try await environment.service.execute(subcommand: command, environment: environment)
                    _ = try environment.service.decodeEvent(VersionsLogEvent.self, from: result.stdout)
                    purchasedKeys.insert(key)
                    return
                } catch let error as IpatoolError {
                    if case .commandFailed(let message) = error,
                       message.localizedCaseInsensitiveContains("license is required") {
                        continue commandLoop
                    }
                    attempt += 1
                    if attempt < 2 {
                        try? await Task.sleep(nanoseconds: 400_000_000)
                    }
                } catch {
                    attempt += 1
                    if attempt < 2 {
                        try? await Task.sleep(nanoseconds: 400_000_000)
                    }
                }
            }

            remainingRetries -= 1
            if remainingRetries <= 0 { break }
        }

        if remainingRetries <= 0 {
            await MainActor.run {
                activeError = .commandFailed("Couldn't verify ownership. Check your network connection and try again.")
            }
        } else {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await self?.runPurchaseCheck(for: app, environment: environment)
            }
        }
    }

    func purchaseKey(for app: IpatoolApp) -> String? {
        if let bundle = app.bundleID, !bundle.isEmpty {
            return purchaseKey(forBundle: bundle)
        }
        if let trackID = app.trackID {
            return purchaseKey(forTrackID: trackID)
        }
        return nil
    }

    func purchaseKey(forBundle bundle: String) -> String {
        "bundle::\(bundle.lowercased())"
    }

    func purchaseKey(forTrackID trackID: Int64) -> String {
        "track::\(trackID)"
    }

    func listVersionsCommands(for app: IpatoolApp) -> [[String]] {
        var commands: [[String]] = []
        if let bundle = app.bundleID, !bundle.isEmpty {
            commands.append(["list-versions", "--bundle-identifier", bundle])
        }
        if let trackID = app.trackID {
            commands.append(["list-versions", "--app-id", String(trackID)])
        }
        return commands
    }

    enum LookupService {
        struct Response: Decodable {
            struct Result: Decodable {
                let trackId: Int64
                let artworkUrl60: String?
                let artworkUrl100: String?
                let artworkUrl512: String?
            }

            let results: [Result]
        }

        static func lookupArtwork(trackIDs: [Int64]) async throws -> [Int64: URL] {
            let batchSize = 50
            var map: [Int64: URL] = [:]
            var currentIndex = 0
            while currentIndex < trackIDs.count {
                let chunk = Array(trackIDs[currentIndex..<min(currentIndex + batchSize, trackIDs.count)])
                let idsParam = chunk.map(String.init).joined(separator: ",")
                guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(idsParam)") else { break }
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(Response.self, from: data)
                for result in response.results {
                    if let urlString = result.artworkUrl512 ?? result.artworkUrl100 ?? result.artworkUrl60,
                       let parsedURL = URL(string: urlString) {
                        map[result.trackId] = parsedURL
                    }
                }
                currentIndex += batchSize
            }
            return map
        }
    }
}

actor AsyncSemaphore {
    private let limit: Int
    private var current = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func wait() async {
        if current < limit {
            current += 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if !waiters.isEmpty {
            let continuation = waiters.removeFirst()
            continuation.resume()
        } else {
            current = max(0, current - 1)
        }
    }
}
