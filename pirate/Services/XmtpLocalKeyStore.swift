import Foundation
import Security

#if canImport(XMTPiOS)
import XMTPiOS
#endif

enum XmtpLocalKeyStoreError: Error, LocalizedError {
    case randomBytesUnavailable
    case invalidStoredKey

    var errorDescription: String? {
        switch self {
        case .randomBytesUnavailable:
            return "Could not generate secure random bytes."
        case .invalidStoredKey:
            return "Stored XMTP identity key is invalid."
        }
    }
}

final class XmtpLocalKeyStore {
    private let service = "psc.pirate.xmtp"
    private let signerPrefix = "xmtp_identity_key:"
    private let dbKeyPrefix = "xmtp_db_key:"

    #if canImport(XMTPiOS)
    func getOrCreateSigner(for userAddress: String) throws -> PrivateKey {
        let account = "\(signerPrefix)\(userAddress.lowercased())"
        if let stored = load(account: account) {
            do {
                return try PrivateKey(stored)
            } catch {
                delete(account: account)
            }
        }

        let signer = try generatePrivateKey()
        save(account: account, data: signer.secp256K1.bytes)
        return signer
    }
    #endif

    func getOrCreateDatabaseKey(for identity: String) throws -> Data {
        let account = "\(dbKeyPrefix)\(identity.lowercased())"
        if let stored = load(account: account), stored.count == 32 {
            return stored
        }

        let key = try secureRandomData(count: 32)
        save(account: account, data: key)
        return key
    }

    #if canImport(XMTPiOS)
    private func generatePrivateKey() throws -> PrivateKey {
        var lastError: Error?
        for _ in 0..<8 {
            do {
                return try PrivateKey(secureRandomData(count: 32))
            } catch {
                lastError = error
            }
        }
        throw lastError ?? XmtpLocalKeyStoreError.invalidStoredKey
    }
    #endif

    private func secureRandomData(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw XmtpLocalKeyStoreError.randomBytesUnavailable
        }
        return Data(bytes)
    }

    private func save(account: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
