import Foundation

// MARK: - Verification
extension ApiClient {
    func createAltchaChallenge(scope: String, action: String) async throws -> AltchaChallenge {
        return try await request(
            path: "/verification/altcha/challenge",
            queryItems: [
                URLQueryItem(name: "scope", value: scope),
                URLQueryItem(name: "action", value: action)
            ]
        )
    }

    func refreshPassportWalletScore(communityId: String? = nil) async throws -> RefreshPassportWalletScoreResponse {
        return try await request(
            path: "/verification/passport-wallet-score",
            method: .POST,
            body: encode(RefreshPassportWalletScoreRequest(communityId: communityId))
        )
    }

    func startVerificationSession(sessionRequest: StartVerificationSessionRequest) async throws -> VerificationSession {
        return try await request(path: "/verification-sessions", method: .POST, body: encode(sessionRequest))
    }

    func verificationSession(id: String) async throws -> VerificationSession {
        return try await request(path: "/verification-sessions/\(pathSegment(id))")
    }

    func completeVerificationSession(id: String, request completeRequest: CompleteVerificationSessionRequest) async throws -> VerificationSession {
        return try await request(
            path: "/verification-sessions/\(pathSegment(id))/complete",
            method: .POST,
            body: encode(completeRequest)
        )
    }

    func startNamespaceSession(family: String, rootLabel: String) async throws -> NamespaceVerificationSession {
        let body = StartNamespaceVerificationSessionRequest(family: family, rootLabel: rootLabel)
        return try await request(path: "/namespace-verification-sessions", method: .POST, body: encode(body))
    }

    func namespaceSession(id: String) async throws -> NamespaceVerificationSession {
        return try await request(path: "/namespace-verification-sessions/\(pathSegment(id))")
    }

    func completeNamespaceSession(id: String, restartChallenge: Bool? = nil) async throws -> NamespaceVerificationSession {
        let body = CompleteNamespaceVerificationSessionRequest(restartChallenge: restartChallenge)
        return try await request(path: "/namespace-verification-sessions/\(pathSegment(id))/complete", method: .POST, body: encode(body))
    }
}
