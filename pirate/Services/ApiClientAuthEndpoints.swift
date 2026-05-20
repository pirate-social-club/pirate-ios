import Foundation

// MARK: - Auth
extension ApiClient {
    func communityDetails(id: String) async throws -> Community {
        return try await request(path: "/communities/\(pathSegment(id))")
    }

    func exchangeSession(proof: SessionExchangeProof) async throws -> SessionExchangeResponse {
        let body = SessionExchangeRequest(proof: proof)
        return try await request(path: "/auth/session/exchange", method: .POST, body: encode(body), requireAuth: false)
    }

    func currentUser() async throws -> User {
        return try await request(path: "/users/me")
    }

}
