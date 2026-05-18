import Foundation

final class SessionRefresher {
    static let shared = SessionRefresher()

    private let refreshWindowMs: Double = 5 * 60 * 1000
    private let maxRetries: Int = 2
    private let retryDelayMs: Double = 30 * 1000

    private var refreshTask: Task<Void, Never>?
    private var isRefreshing = false

    private init() {}

    func start() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionDidChange),
            name: .sessionDidChange,
            object: nil
        )
        scheduleRefresh()
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func sessionDidChange() {
        scheduleRefresh()
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()

        let sessionStore = SessionStore.shared
        guard let session = sessionStore.currentSession else { return }

        let tokenExpiry = SessionExpiry.accessTokenExpiryMs(session.accessToken)
        guard tokenExpiry > 0 else { return }

        let now = Date().timeIntervalSince1970 * 1000
        let refreshAt = tokenExpiry - refreshWindowMs
        let delay = max(0, (refreshAt - now) / 1000)

        refreshTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await attemptRefresh()
        }
    }

    private func attemptRefresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        var attempts = 0
        while attempts < maxRetries {
            do {
                try await refreshToken()
                return
            } catch {
                attempts += 1
                if attempts < maxRetries {
                    try? await Task.sleep(for: .milliseconds(Int(retryDelayMs)))
                }
            }
        }
    }

    private func refreshToken() async throws {
        let sessionStore = SessionStore.shared
        guard let session = sessionStore.currentSession else { return }

        let tokenExpiry = SessionExpiry.accessTokenExpiryMs(session.accessToken)
        let now = Date().timeIntervalSince1970 * 1000
        if tokenExpiry > 0 && now < tokenExpiry - (refreshWindowMs / 2) {
            return
        }

        let authService = AuthService.shared
        authService.initialize()

        guard let proof = await authService.sessionExchangeProof() else {
            SessionStore.shared.clear()

            await MainActor.run {
                NotificationCenter.default.post(name: .sessionDidChange, object: nil)
            }
            return
        }

        let newSession = try await ApiClient.shared.exchangeSession(proof: proof)
        SessionStore.shared.set(newSession)

        await MainActor.run {
            NotificationCenter.default.post(name: .sessionDidChange, object: nil)
        }
    }
}

enum SessionExpiry {
    static func accessTokenExpiryMs(_ token: String) -> Double {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return 0 }
        let payloadSegment = String(segments[1])
        guard let payloadData = Data(base64Encoded: payloadSegment.padBase64()) else { return 0 }
        guard let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = json["exp"] as? Double else { return 0 }
        return exp * 1000
    }
}
