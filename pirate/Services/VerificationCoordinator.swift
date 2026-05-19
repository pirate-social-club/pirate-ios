import Foundation
import Observation

struct PendingVerificationSession: Codable, Equatable {
    let provider: String
    let verificationSessionId: String
}

enum VerificationCallbackResult: Equatable {
    case completed(provider: String, verificationSessionId: String?, proof: String)
    case failed(provider: String, verificationSessionId: String?, reason: String)
    case expired(provider: String, verificationSessionId: String?)

    var provider: String {
        switch self {
        case .completed(let provider, _, _), .failed(let provider, _, _), .expired(let provider, _):
            return provider
        }
    }
}

@MainActor
@Observable
final class VerificationCoordinator {
    static let shared = VerificationCoordinator()

    var callbackResult: VerificationCallbackResult?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func savePendingSession(_ session: PendingVerificationSession) {
        defaults.set(session.provider, forKey: Self.providerKey)
        defaults.set(session.verificationSessionId, forKey: Self.sessionIdKey)
    }

    func readPendingSession() -> PendingVerificationSession? {
        guard
            let provider = defaults.string(forKey: Self.providerKey)?.nilIfEmpty,
            let verificationSessionId = defaults.string(forKey: Self.sessionIdKey)?.nilIfEmpty
        else {
            return nil
        }
        return PendingVerificationSession(provider: provider, verificationSessionId: verificationSessionId)
    }

    func clearPendingSession() {
        defaults.removeObject(forKey: Self.providerKey)
        defaults.removeObject(forKey: Self.sessionIdKey)
    }

    func clearCallbackResult() {
        callbackResult = nil
    }

    func handleOpenURL(_ url: URL) {
        guard let callback = parseVerificationCallback(url) else { return }
        callbackResult = callback
    }

    static func buildCallbackURL(verificationSessionId: String, provider: String) -> URL? {
        var components = URLComponents()
        components.scheme = "pirate"
        components.host = "verification"
        components.path = "/callback"
        components.queryItems = [
            URLQueryItem(name: "provider", value: provider),
            URLQueryItem(name: "verification_session_id", value: verificationSessionId)
        ]
        return components.url
    }

    private func parseVerificationCallback(_ url: URL) -> VerificationCallbackResult? {
        guard Self.isVerificationCallback(url), let pendingSession = readPendingSession() else {
            return nil
        }

        let provider = callbackParam("provider", in: url)?.nilIfEmpty ?? pendingSession.provider
        guard provider == pendingSession.provider else { return nil }

        let verificationSessionId = callbackParam("verification_session_id", in: url)?.nilIfEmpty
            ?? callbackParam("self_verification_session_id", in: url)?.nilIfEmpty
            ?? pendingSession.verificationSessionId
        guard verificationSessionId == pendingSession.verificationSessionId else { return nil }

        if let proof = callbackParam("proof", in: url)?.nilIfEmpty {
            return .completed(provider: provider, verificationSessionId: verificationSessionId, proof: proof)
        }

        if callbackParam("expired", in: url) == "true" {
            return .expired(provider: provider, verificationSessionId: verificationSessionId)
        }

        if let error = callbackParam("error", in: url)?.nilIfEmpty {
            return .failed(provider: provider, verificationSessionId: verificationSessionId, reason: error)
        }

        return nil
    }

    private func callbackParam(_ name: String, in url: URL) -> String? {
        if let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value {
            return value
        }
        return Self.fragmentParam(name, in: url.fragment)
    }

    private static func isVerificationCallback(_ url: URL) -> Bool {
        url.scheme == "pirate" && url.host == "verification" && url.path == "/callback"
    }

    private static func fragmentParam(_ name: String, in fragment: String?) -> String? {
        guard let fragment, !fragment.isEmpty else { return nil }
        let rawParams = fragment
            .split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            .last
            .map(String.init) ?? fragment
        guard rawParams.contains("=") else { return nil }

        var components = URLComponents()
        components.query = rawParams.hasPrefix("?") ? String(rawParams.dropFirst()) : rawParams
        return components.queryItems?.first(where: { $0.name == name })?.value
    }

    private static let providerKey = "pirate_verification_pending_provider"
    private static let sessionIdKey = "pirate_verification_pending_session_id"
}
