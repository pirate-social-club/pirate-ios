import Foundation
#if canImport(PrivySDK)
import PrivySDK
#endif

enum PrivyLoginProvider {
    case google
    case twitter
}

#if canImport(PrivySDK)
typealias PiratePrivyClient = any Privy
typealias PiratePrivyUser = any PrivyUser
#else
typealias PiratePrivyUser = PrivyUser
#endif

@Observable
final class AuthService {
    static let shared = AuthService()

    var authState: AuthState = .idle
    var privyUser: PiratePrivyUser?
    private var initialized = false

    enum AuthState: Equatable {
        case idle
        case loading
        case authenticated
        case unauthenticated
        case error(String)
    }

    func initialize() {
        if initialized { return }
        initialized = true

        #if canImport(PrivySDK)
        let appId = PiratePrivyConfig.appId
        let appClientId = PiratePrivyConfig.appClientId

        guard !appId.isEmpty, !appClientId.isEmpty else {
            authState = .error("Privy is not configured. Set PRIVY_APP_ID and PRIVY_APP_CLIENT_ID.")
            return
        }

        let config = PrivyConfig(
            appId: appId,
            appClientId: appClientId
        )

        let privy = PrivySdk.initialize(config: config)
        self.privy = privy
        #else
        authState = .error("Privy SDK not available on this platform")
        #endif
    }

    #if canImport(PrivySDK)
    private var privy: PiratePrivyClient?

    @discardableResult
    func refreshAuthState() async -> PiratePrivyUser? {
        initialize()
        guard let privy = privy else { return nil }
        let state = await privy.getAuthState()
        switch state {
        case .authenticated(let user):
            self.privyUser = user
            self.authState = .authenticated
            return user
        case .unauthenticated:
            self.privyUser = nil
            self.authState = .unauthenticated
        case .notReady:
            self.authState = .loading
        case .authenticatedUnverified(_):
            if let user = await privy.getUser() {
                self.privyUser = user
                self.authState = .authenticated
                return user
            }
            self.authState = .loading
        @unknown default:
            break
        }
        return nil
    }

    func loginWithGoogle() async {
        await loginWithOAuth(.google)
    }

    func loginWithTwitter() async {
        await loginWithOAuth(.twitter)
    }

    private func loginWithOAuth(_ provider: PrivyLoginProvider) async {
        initialize()
        guard let privy = privy else {
            authState = .error("Privy not initialized")
            return
        }
        authState = .loading
        do {
            let user: PiratePrivyUser
            switch provider {
            case .google:
                user = try await privy.oAuth.login(
                    with: OAuthProvider.google,
                    appUrlScheme: PiratePrivyConfig.redirectScheme
                )
            case .twitter:
                user = try await privy.oAuth.login(
                    with: OAuthProvider.twitter,
                    appUrlScheme: PiratePrivyConfig.redirectScheme
                )
            }
            self.privyUser = user
            self.authState = .authenticated
        } catch {
            self.authState = .error(error.localizedDescription)
        }
    }

    func sendEmailCode(_ email: String) async throws {
        initialize()
        guard let privy = privy else {
            throw AuthError.notInitialized
        }
        try await privy.email.sendCode(to: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func loginWithEmailCode(_ code: String, email: String) async {
        initialize()
        guard let privy = privy else {
            authState = .error("Privy not initialized")
            return
        }
        authState = .loading
        do {
            let user = try await privy.email.loginWithCode(
                code.trimmingCharacters(in: .whitespacesAndNewlines),
                sentTo: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            self.privyUser = user
            self.authState = .authenticated
        } catch {
            self.authState = .error(error.localizedDescription)
        }
    }

    func getAccessToken() async -> String? {
        let user: PiratePrivyUser?
        if let currentUser = privyUser {
            user = currentUser
        } else {
            user = await refreshAuthState()
        }
        do {
            return try await user?.getAccessToken()
        } catch {
            return nil
        }
    }

    func sessionExchangeProof() async -> SessionExchangeProof? {
        guard let token = await getAccessToken() else { return nil }
        let walletAddress = privyUser?.embeddedEthereumWallets.first?.address
        return SessionExchangeProof(
            type: "privy_access_token",
            privyAccessToken: token,
            walletAddress: walletAddress
        )
    }

    func logout() async {
        initialize()
        let user: PiratePrivyUser?
        if let currentUser = privyUser {
            user = currentUser
        } else {
            user = await refreshAuthState()
        }
        await user?.logout()
        self.privyUser = nil
        self.authState = .unauthenticated
    }
    #else
    func refreshAuthState() async -> PiratePrivyUser? { return nil }
    func loginWithGoogle() async { authState = .error("Privy SDK not available") }
    func loginWithTwitter() async { authState = .error("Privy SDK not available") }
    func sendEmailCode(_ email: String) async throws { throw AuthError.notInitialized }
    func loginWithEmailCode(_ code: String, email: String) async { authState = .error("Privy SDK not available") }
    func getAccessToken() async -> String? { return nil }
    func sessionExchangeProof() async -> SessionExchangeProof? { return nil }
    func logout() async { self.privyUser = nil; self.authState = .unauthenticated }
    #endif

    var isConfigured: Bool {
        !PiratePrivyConfig.appId.isEmpty
            && !PiratePrivyConfig.appClientId.isEmpty
            && !PiratePrivyConfig.redirectScheme.isEmpty
    }
}

enum AuthError: Error {
    case notInitialized
}

enum PiratePrivyConfig {
    static var appId: String {
        ProcessInfo.processInfo.environment["PRIVY_APP_ID"]
            ?? "cmnbdx9xk00ty0clapn2q8pdj"
    }

    static var appClientId: String {
        ProcessInfo.processInfo.environment["PRIVY_APP_CLIENT_ID"]
            ?? "client-WY6Xkpp2wLef8Y9cWBrZ1GhnmqAtnVh9YiqXDA1YWsrYG"
    }

    static var redirectScheme: String {
        ProcessInfo.processInfo.environment["PRIVY_REDIRECT_SCHEME"]
            ?? "pirate"
    }
}

#if !canImport(PrivySDK)
struct PrivyUser {
    let id: String
    var embeddedEthereumWallets: [EmbeddedEthereumWallet] = []
}

struct EmbeddedEthereumWallet {
    let address: String
}
#endif
