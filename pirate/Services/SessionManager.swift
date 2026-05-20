import SwiftUI
import Observation

@Observable
final class SessionManager {
    var currentSession: SessionExchangeResponse?
    var isRestoringSession = false
    var isAuthenticated: Bool { currentSession != nil }
    var profile: Profile? { currentSession?.profile }
    var user: User? { currentSession?.user }
    var primaryWalletAddress: String? {
        currentSession?.profile.primaryWalletAddress?.nilIfEmpty
            ?? primaryWalletAddress(from: currentSession?.walletAttachments)
    }

    private let sessionStore: SessionStore
    private let apiClient: ApiClient
    private let authService: AuthService

    init(sessionStore: SessionStore = .shared, apiClient: ApiClient = .shared, authService: AuthService = .shared) {
        self.sessionStore = sessionStore
        self.apiClient = apiClient
        self.authService = authService
        Task { @MainActor in
            await restoreSession()
        }
    }

    func restoreSession() async {
        isRestoringSession = true
        defer { isRestoringSession = false }

        if let session = sessionStore.currentSession {
            self.currentSession = session
            apiClient.setAccessToken(session.accessToken)
            return
        }

        authService.initialize()
        await authService.refreshAuthState()
        guard let proof = await authService.sessionExchangeProof() else {
            return
        }

        do {
            let session = try await apiClient.exchangeSession(proof: proof)
            setSession(session)
        } catch {
            await authService.logout()
        }
    }

    func setSession(_ session: SessionExchangeResponse) {
        self.currentSession = session
        sessionStore.set(session)
        apiClient.setAccessToken(session.accessToken)
    }

    func refreshProfile() async {
        guard let currentSession else { return }
        do {
            let profile = try await apiClient.myProfile()
            let refreshed = SessionExchangeResponse(
                accessToken: currentSession.accessToken,
                user: currentSession.user,
                profile: profile,
                onboarding: currentSession.onboarding,
                walletAttachments: currentSession.walletAttachments
            )
            setSession(refreshed)
        } catch {}
    }

    func refreshUser() async {
        guard let currentSession else { return }
        do {
            let user = try await apiClient.currentUser()
            let refreshed = SessionExchangeResponse(
                accessToken: currentSession.accessToken,
                user: user,
                profile: currentSession.profile,
                onboarding: currentSession.onboarding,
                walletAttachments: currentSession.walletAttachments
            )
            setSession(refreshed)
        } catch {}
    }

    func logout() async {
        await authService.logout()
        self.currentSession = nil
        sessionStore.clear()
        apiClient.setAccessToken(nil)
    }

    private func primaryWalletAddress(from attachments: [WalletAttachmentSummary]?) -> String? {
        guard let attachments else { return nil }
        let primary = attachments.first { $0.isPrimary == true && $0.walletAddress.nilIfEmpty != nil }
        return primary?.walletAddress.nilIfEmpty
            ?? attachments.first { $0.walletAddress.nilIfEmpty != nil }?.walletAddress.nilIfEmpty
    }
}
