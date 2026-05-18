import Foundation

#if canImport(XMTPiOS)
import XMTPiOS
#endif

enum XmtpAddressing {
    static func normalizeEthereumAddress(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixed = trimmed.lowercased().hasPrefix("0x") ? trimmed : "0x\(trimmed)"
        let lower = prefixed.lowercased()
        guard lower.count == 42, lower.hasPrefix("0x") else {
            throw XmtpAddressingError.invalidEthereumAddress
        }
        guard lower.dropFirst(2).allSatisfy({ $0.isHexCharacter }) else {
            throw XmtpAddressingError.invalidEthereumAddress
        }
        return lower
    }

    static func normalizeEthereumAddressOrNil(_ value: String) -> String? {
        try? normalizeEthereumAddress(value)
    }

    static func looksLikeEthereumAddress(_ value: String) -> Bool {
        normalizeEthereumAddressOrNil(value) != nil
    }

    static func looksLikeXmtpInboxId(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy(\.isHexCharacter)
    }
}

enum XmtpAddressingError: Error, LocalizedError {
    case invalidEthereumAddress
    case missingTarget
    case noInbox(String)

    var errorDescription: String? {
        switch self {
        case .invalidEthereumAddress:
            return "Invalid Ethereum address."
        case .missingTarget:
            return "Missing address, inbox ID, or handle."
        case .noInbox(let target):
            return "No XMTP inbox for \(target)."
        }
    }
}

#if canImport(XMTPiOS)
final class XmtpPeerResolver {
    private let apiClient: ApiClient
    private let defaults: UserDefaults
    private var peerAddressByInboxId: [String: String] = [:]
    private var peerIdentityByAddress: [String: XmtpResolvedPeerIdentity] = [:]

    init(apiClient: ApiClient = .shared, defaults: UserDefaults = .standard) {
        self.apiClient = apiClient
        self.defaults = defaults
    }

    func resolveInboxId(client: Client, rawAddressOrInboxId: String) async throws -> String {
        let trimmed = rawAddressOrInboxId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw XmtpAddressingError.missingTarget }

        let normalizedAddress: String?
        if trimmed.lowercased().hasPrefix("0x") {
            normalizedAddress = try XmtpAddressing.normalizeEthereumAddress(trimmed)
        } else if trimmed.count == 40 && trimmed.allSatisfy(\.isHexCharacter) {
            normalizedAddress = try XmtpAddressing.normalizeEthereumAddress("0x\(trimmed)")
        } else {
            normalizedAddress = nil
        }

        if let normalizedAddress {
            let identity = PublicIdentity(kind: .ethereum, identifier: normalizedAddress)
            if let inboxId = try await client.inboxIdFromIdentity(identity: identity), !inboxId.isEmpty {
                return inboxId
            }
            throw XmtpAddressingError.noInbox(normalizedAddress)
        }

        if XmtpAddressing.looksLikeXmtpInboxId(trimmed) {
            return trimmed
        }

        if let handle = normalizeHandleTarget(trimmed),
           let resolved = try await resolveHandleLikeTarget(client: client, rawTarget: handle) {
            return resolved
        }

        throw XmtpAddressingError.noInbox(normalizeHandleTarget(trimmed) ?? trimmed)
    }

    func resolvePeerAddress(client: Client, peerInboxId: String) async -> String {
        if let cached = peerAddressByInboxId[peerInboxId] {
            return cached
        }
        if let persisted = loadPersistedAddress(for: peerInboxId) {
            peerAddressByInboxId[peerInboxId] = persisted
            return persisted
        }

        do {
            let localState = try await client.inboxStatesForInboxIds(refreshFromNetwork: false, inboxIds: [peerInboxId]).first
            let networkState: InboxState?
            if let localState {
                networkState = localState
            } else {
                networkState = try await client.inboxStatesForInboxIds(refreshFromNetwork: true, inboxIds: [peerInboxId]).first
            }
            let address = networkState?.identities
                .first(where: { $0.kind == .ethereum })
                .flatMap { XmtpAddressing.normalizeEthereumAddressOrNil($0.identifier) }

            if let address {
                peerAddressByInboxId[peerInboxId] = address
                persist(address: address, for: peerInboxId)
                return address
            }
        } catch {}

        return peerInboxId
    }

    func resolvePeerIdentity(addressOrInboxId: String) async -> XmtpResolvedPeerIdentity {
        guard let address = XmtpAddressing.normalizeEthereumAddressOrNil(addressOrInboxId) else {
            return XmtpResolvedPeerIdentity(displayName: addressOrInboxId, avatarRef: nil)
        }
        if let cached = peerIdentityByAddress[address] {
            return cached
        }

        do {
            let resolution = try await apiClient.publicProfileByWallet(address: address)
            let profile = resolution.profile
            let resolvedHandleLabel = resolution.resolvedHandleLabels?.first ?? ""
            let identity = XmtpResolvedPeerIdentity(
                displayName: profile.chatDisplayName(resolvedHandleLabel: resolvedHandleLabel),
                avatarRef: profile.chatAvatarRef(resolvedHandleLabel: resolvedHandleLabel)
            )
            peerIdentityByAddress[address] = identity
            return identity
        } catch {
            return XmtpResolvedPeerIdentity(displayName: address, avatarRef: nil)
        }
    }

    func clearCaches() {
        peerAddressByInboxId.removeAll()
        peerIdentityByAddress.removeAll()
    }

    private func resolveHandleLikeTarget(client: Client, rawTarget: String) async throws -> String? {
        let handle = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !handle.isEmpty, handle.count <= 120, !handle.contains(where: \.isWhitespace) else {
            return nil
        }

        let profile = try await apiClient.publicProfile(handle: handle).profile
        if let inboxId = profile.xmtpInbox?.trimmedNonEmpty {
            return inboxId
        }
        guard let wallet = profile.primaryWalletAddress?.trimmedNonEmpty,
              let normalized = XmtpAddressing.normalizeEthereumAddressOrNil(wallet) else {
            return nil
        }
        return try await client.inboxIdFromIdentity(identity: PublicIdentity(kind: .ethereum, identifier: normalized))
    }

    private func normalizeHandleTarget(_ rawTarget: String) -> String? {
        var value = rawTarget
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .withoutPrefix("@")
            .components(separatedBy: "?").first ?? rawTarget
        value = value.components(separatedBy: "#").first ?? value
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        value = value.withoutPrefix("https://").withoutPrefix("http://")
        value = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if value.lowercased().hasPrefix("pirate.sc/") {
            value = String(value.dropFirst("pirate.sc/".count))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        if value.lowercased().hasPrefix("u/") {
            value = String(value.dropFirst(2))
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }

        return value.withoutPrefix("@").trimmedNonEmpty
    }

    private func loadPersistedAddress(for inboxId: String) -> String? {
        defaults.string(forKey: "xmtp_inbox_address:\(inboxId.lowercased())")?.trimmedNonEmpty
    }

    private func persist(address: String, for inboxId: String) {
        defaults.set(address.lowercased(), forKey: "xmtp_inbox_address:\(inboxId.lowercased())")
    }
}
#endif

private extension Profile {
    func chatDisplayName(resolvedHandleLabel: String) -> String {
        displayName?.trimmedNonEmpty
            ?? resolvedHandleLabel.trimmedNonEmpty
            ?? primaryPublicHandle?.label.trimmedNonEmpty
            ?? globalHandle?.label.trimmedNonEmpty
            ?? primaryWalletAddress.flatMap(XmtpAddressing.normalizeEthereumAddressOrNil)
            ?? userId.trimmedNonEmpty
            ?? "Pirate"
    }

    func chatAvatarRef(resolvedHandleLabel: String) -> String? {
        avatarRef?.trimmedNonEmpty
    }
}

private extension Character {
    var isHexCharacter: Bool {
        guard let scalar = lowercased().unicodeScalars.first else { return false }
        return (48...57).contains(Int(scalar.value)) || (97...102).contains(Int(scalar.value))
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func withoutPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
