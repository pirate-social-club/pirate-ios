import Foundation

final class SessionStore {
    static let shared = SessionStore()

    private let keychainService = "psc.pirate"
    private let sessionKey = "pirate_session"

    private var cachedSession: SessionExchangeResponse?
    private var cacheLoaded = false

    var currentSession: SessionExchangeResponse? {
        if !cacheLoaded { loadFromKeychain() }
        let session = cachedSession
        if let session = session, isTokenExpired(session.accessToken) {
            cachedSession = nil
            deleteFromKeychain()
            return nil
        }
        return cachedSession
    }

    var isAuthenticated: Bool {
        currentSession != nil
    }

    var accessToken: String? {
        currentSession?.accessToken
    }

    var currentProfile: Profile? {
        currentSession?.profile
    }

    var currentUser: User? {
        currentSession?.user
    }

    var primaryWalletAddress: String? {
        currentSession?.profile.primaryWalletAddress?.nilIfEmpty
            ?? primaryWalletAddress(from: currentSession?.walletAttachments)
    }

    func set(_ session: SessionExchangeResponse) {
        cachedSession = session
        cacheLoaded = true
        saveToKeychain(session)
        NotificationCenter.default.post(name: .sessionDidChange, object: nil)
    }

    func clear() {
        cachedSession = nil
        cacheLoaded = true
        deleteFromKeychain()
        NotificationCenter.default.post(name: .sessionDidChange, object: nil)
    }

    private func loadFromKeychain() {
        cacheLoaded = true
        guard let data = loadFromKeychain(key: sessionKey) else { return }
        do {
            cachedSession = try JSONDecoder().decode(SessionExchangeResponse.self, from: data)
        } catch {
            cachedSession = nil
        }
    }

    private func saveToKeychain(_ session: SessionExchangeResponse) {
        do {
            let data = try JSONEncoder().encode(session)
            saveToKeychain(key: sessionKey, data: data)
        } catch {}
    }

    private func deleteFromKeychain() {
        deleteFromKeychain(key: sessionKey)
    }

    private func isTokenExpired(_ token: String) -> Bool {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return false }
        let payloadSegment = String(segments[1])
        guard let payloadData = Data(base64Encoded: payloadSegment.padBase64()) else { return false }
        guard let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = json["exp"] as? Double else { return false }
        return Date(timeIntervalSince1970: exp) <= Date()
    }

    private func primaryWalletAddress(from attachments: [WalletAttachmentSummary]?) -> String? {
        guard let attachments else { return nil }
        let primary = attachments.first { $0.isPrimary == true && $0.walletAddress.nilIfEmpty != nil }
        return primary?.walletAddress.nilIfEmpty
            ?? attachments.first { $0.walletAddress.nilIfEmpty != nil }?.walletAddress.nilIfEmpty
    }

    private func saveToKeychain(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func loadFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

extension String {
    func padBase64() -> String {
        let remainder = count % 4
        if remainder == 0 { return self }
        return self + String(repeating: "=", count: 4 - remainder)
    }
}

extension Notification.Name {
    static let sessionDidChange = Notification.Name("sessionDidChange")
}
