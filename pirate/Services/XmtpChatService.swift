import Foundation
import Observation

#if canImport(XMTPiOS)
import XMTPiOS
#endif

enum XmtpChatServiceError: Error, LocalizedError {
    case sdkUnavailable
    case missingWalletAddress
    case notConnected
    case noActiveConversation

    var errorDescription: String? {
        switch self {
        case .sdkUnavailable:
            return "XMTP iOS SDK is not linked."
        case .missingWalletAddress:
            return "Missing wallet address."
        case .notConnected:
            return "XMTP is not connected."
        case .noActiveConversation:
            return "No active conversation."
        }
    }
}

@MainActor
@Observable
final class XmtpChatService {
    static let shared = XmtpChatService()

    private(set) var isConnected = false
    private(set) var isConnecting = false
    private(set) var connectedAddress: String?
    private(set) var currentInboxId: String?
    private(set) var conversations: [XmtpConversationItem] = []
    private(set) var messages: [XmtpChatMessage] = []
    private(set) var activeConversationId: String?
    private(set) var unreadCount = 0
    var lastErrorMessage: String?

    #if canImport(XMTPiOS)
    @ObservationIgnored private let keyStore = XmtpLocalKeyStore()
    @ObservationIgnored private let peerResolver = XmtpPeerResolver()
    @ObservationIgnored private var client: Client?
    @ObservationIgnored private var activeConversation: Conversation?
    @ObservationIgnored private var messageStreamTask: Task<Void, Never>?
    @ObservationIgnored private var chatVisible = false
    #endif

    func connect(walletAddress: String) async throws {
        #if canImport(XMTPiOS)
        let normalizedAddress = try XmtpAddressing.normalizeEthereumAddress(walletAddress)
        if client != nil, connectedAddress == normalizedAddress {
            return
        }
        if client != nil, connectedAddress != normalizedAddress {
            disconnect()
        }

        isConnecting = true
        lastErrorMessage = nil
        defer { isConnecting = false }

        do {
            let signer = try keyStore.getOrCreateSigner(for: normalizedAddress)
            let dbDirectory = try xmtpDatabaseDirectory()
            let options = ClientOptions(
                api: .init(env: Self.xmtpEnvironment(), isSecure: true),
                dbEncryptionKey: try keyStore.getOrCreateDatabaseKey(for: signer.identity.identifier),
                dbDirectory: dbDirectory.path
            )
            let connectedClient = try await createClientWithDatabaseRecovery(
                signer: signer,
                options: options,
                dbDirectory: dbDirectory
            )

            client = connectedClient
            connectedAddress = normalizedAddress
            currentInboxId = connectedClient.inboxID
            isConnected = true
            try await refreshConversations()
            startMessageStream()
        } catch {
            lastErrorMessage = error.localizedDescription
            throw error
        }
        #else
        throw XmtpChatServiceError.sdkUnavailable
        #endif
    }

    func disconnect() {
        #if canImport(XMTPiOS)
        messageStreamTask?.cancel()
        messageStreamTask = nil
        client = nil
        activeConversation = nil
        peerResolver.clearCaches()
        chatVisible = false
        #endif
        isConnected = false
        isConnecting = false
        connectedAddress = nil
        currentInboxId = nil
        conversations = []
        messages = []
        activeConversationId = nil
        unreadCount = 0
    }

    func setChatVisible(_ visible: Bool) {
        #if canImport(XMTPiOS)
        chatVisible = visible
        #endif
        if visible {
            unreadCount = 0
        }
    }

    func refreshConversations() async throws {
        #if canImport(XMTPiOS)
        guard let client else { return }
        do {
            _ = try await client.conversations.syncAllConversations()
            let dms = try client.conversations.listDms()
            let groups = try client.conversations.listGroups()

            var items: [XmtpConversationItem] = []
            for dm in dms {
                if let item = try await toDmConversationItem(client: client, dm: dm) {
                    items.append(item)
                }
            }
            for group in groups {
                if let item = try await toGroupConversationItem(group: group) {
                    items.append(item)
                }
            }

            conversations = items.sorted {
                ($0.lastMessageDate ?? .distantPast) > ($1.lastMessageDate ?? .distantPast)
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            throw error
        }
        #else
        throw XmtpChatServiceError.sdkUnavailable
        #endif
    }

    func openConversation(_ conversationId: String) async throws {
        #if canImport(XMTPiOS)
        guard let client else { throw XmtpChatServiceError.notConnected }
        guard let conversation = try await client.conversations.findConversation(conversationId: conversationId) else {
            return
        }
        activeConversationId = conversationId
        activeConversation = conversation
        try await conversation.sync()
        try await loadMessages(conversation)
        #else
        throw XmtpChatServiceError.sdkUnavailable
        #endif
    }

    func closeConversation() {
        #if canImport(XMTPiOS)
        activeConversation = nil
        #endif
        activeConversationId = nil
        messages = []
    }

    func sendMessage(_ text: String) async throws {
        #if canImport(XMTPiOS)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let conversation = activeConversation else {
            throw XmtpChatServiceError.noActiveConversation
        }
        _ = try await conversation.send(content: trimmed)
        try await conversation.sync()
        try await loadMessages(conversation)
        try await refreshConversations()
        #else
        throw XmtpChatServiceError.sdkUnavailable
        #endif
    }

    func newDm(_ peerAddressOrInboxId: String) async throws -> String {
        #if canImport(XMTPiOS)
        guard let client else { throw XmtpChatServiceError.notConnected }
        do {
            return try await createDm(client: client, peerAddressOrInboxId: peerAddressOrInboxId)
        } catch {
            try await Task.sleep(nanoseconds: 350_000_000)
            _ = try await client.conversations.syncAllConversations()
            return try await createDm(client: client, peerAddressOrInboxId: peerAddressOrInboxId)
        }
        #else
        throw XmtpChatServiceError.sdkUnavailable
        #endif
    }

    func newGroup(memberTargets: [String], name: String?) async throws -> String {
        #if canImport(XMTPiOS)
        guard let client else { throw XmtpChatServiceError.notConnected }
        let inboxIds = try await resolveMemberInboxIds(client: client, memberTargets: memberTargets)
        let group = try await client.conversations.newGroup(
            with: inboxIds,
            permissions: .allMembers,
            name: name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            imageUrl: "",
            description: ""
        )
        try await refreshConversations()
        return group.id
        #else
        throw XmtpChatServiceError.sdkUnavailable
        #endif
    }

    #if canImport(XMTPiOS)
    private func createDm(client: Client, peerAddressOrInboxId: String) async throws -> String {
        let inboxId = try await peerResolver.resolveInboxId(client: client, rawAddressOrInboxId: peerAddressOrInboxId)
        let dm = try await client.conversations.findOrCreateDm(with: inboxId)
        try await refreshConversations()
        return dm.id
    }

    private func resolveMemberInboxIds(client: Client, memberTargets: [String]) async throws -> [String] {
        var resolved: [String] = []
        for target in memberTargets.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }) where !target.isEmpty {
            let inboxId = try await peerResolver.resolveInboxId(client: client, rawAddressOrInboxId: target)
            if inboxId != client.inboxID, !resolved.contains(inboxId) {
                resolved.append(inboxId)
            }
        }
        guard !resolved.isEmpty else {
            throw XmtpAddressingError.noInbox("members")
        }
        return resolved
    }

    private func loadMessages(_ conversation: Conversation) async throws {
        guard let client else { return }
        let rawMessages = try await conversation.messages(limit: 100)
        let nextMessages = await rawMessages.asyncCompactMap { message -> XmtpChatMessage? in
            let text = sanitizeXmtpBody(message)
            guard !text.isEmpty else { return nil }
            let isFromMe = message.senderInboxId == client.inboxID
            let senderAddress = isFromMe
                ? message.senderInboxId
                : await peerResolver.resolvePeerAddress(client: client, peerInboxId: message.senderInboxId)
            return XmtpChatMessage(
                id: message.id,
                senderAddress: senderAddress,
                senderInboxId: message.senderInboxId,
                text: text,
                sentAt: message.sentAt,
                isFromMe: isFromMe
            )
        }
        messages = nextMessages.sorted { $0.sentAt < $1.sentAt }
    }

    private func toDmConversationItem(client: Client, dm: Dm) async throws -> XmtpConversationItem? {
        let peerInboxId = try dm.peerInboxId
        guard XmtpAddressing.looksLikeXmtpInboxId(peerInboxId) else { return nil }
        let peerAddress = await peerResolver.resolvePeerAddress(client: client, peerInboxId: peerInboxId)
        let peerIdentity = await peerResolver.resolvePeerIdentity(addressOrInboxId: peerAddress)
        let last = try await dm.lastMessage()
        return XmtpConversationItem(
            id: dm.id,
            kind: .dm,
            displayName: peerIdentity.displayName.isEmpty ? peerAddress : peerIdentity.displayName,
            avatarRef: peerIdentity.avatarRef,
            lastMessage: last.map(sanitizeXmtpBody) ?? "",
            lastMessageDate: last?.sentAt,
            subtitle: peerInboxId,
            peerAddress: peerAddress,
            peerInboxId: peerInboxId
        )
    }

    private func toGroupConversationItem(group: Group) async throws -> XmtpConversationItem? {
        let last = try await group.lastMessage()
        let displayName = try group.name().trimmingCharacters(in: .whitespacesAndNewlines)
        let description = try group.description().trimmingCharacters(in: .whitespacesAndNewlines)
        return XmtpConversationItem(
            id: group.id,
            kind: .group,
            displayName: displayName.isEmpty ? "Untitled group" : displayName,
            avatarRef: nil,
            lastMessage: last.map(sanitizeXmtpBody) ?? "",
            lastMessageDate: last?.sentAt,
            subtitle: description.isEmpty ? "Group chat" : description,
            peerAddress: nil,
            peerInboxId: nil
        )
    }

    private func startMessageStream() {
        guard let client else { return }
        messageStreamTask?.cancel()
        messageStreamTask = Task { [weak self] in
            do {
                let stream = client.conversations.streamAllMessages(consentStates: [.allowed])
                for try await message in stream {
                    guard let self else { return }
                    await self.handleStreamedMessage(message)
                }
            } catch {
                await MainActor.run {
                    self?.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func handleStreamedMessage(_ message: DecodedMessage) async {
        guard let client else { return }
        if message.senderInboxId != client.inboxID, !chatVisible {
            unreadCount = min(unreadCount + 1, 99)
        }
        try? await refreshConversations()
        if let activeConversation {
            try? await activeConversation.sync()
            try? await loadMessages(activeConversation)
        }
    }

    private func createClientWithDatabaseRecovery(
        signer: PrivateKey,
        options: ClientOptions,
        dbDirectory: URL
    ) async throws -> Client {
        do {
            return try await Client.create(account: signer, options: options)
        } catch {
            guard isDatabaseKeyOrSaltMismatch(error) else { throw error }
            try resetLocalDatabaseFiles(in: dbDirectory)
            return try await Client.create(account: signer, options: options)
        }
    }

    private func isDatabaseKeyOrSaltMismatch(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("pragma key or salt has incorrect value")
            || message.contains("error decrypting page")
            || message.contains("hmac check failed")
            || message.contains("file is not a database")
    }

    private func resetLocalDatabaseFiles(in directory: URL) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func xmtpDatabaseDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("xmtp_db", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func sanitizeXmtpBody(_ message: DecodedMessage) -> String {
        guard message.kind == .application else { return "" }
        let fallback = ((try? message.fallback) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let body = ((try? message.body) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let text = fallback.isEmpty ? body : fallback
        guard !text.isEmpty, !looksLikeProtocolPrefixedPayload(text) else { return "" }
        return text
    }

    private func looksLikeProtocolPrefixedPayload(_ value: String) -> Bool {
        guard value.hasPrefix("@") else { return false }
        let firstWhitespace = value.firstIndex(where: \.isWhitespace)
        let tokenEnd = firstWhitespace ?? value.endIndex
        let token = String(value[value.index(after: value.startIndex)..<tokenEnd])
        guard token.count >= 20, !token.contains("."), !token.contains(where: \.isWhitespace) else {
            return false
        }
        guard token.allSatisfy({ $0.isLetter || $0.isNumber || "_-=+/".contains($0) }) else {
            return false
        }
        guard let firstWhitespace else { return true }
        return looksLikeEncodedPayloadRemainder(String(value[firstWhitespace...]).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func looksLikeEncodedPayloadRemainder(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        let tokens = value.split(whereSeparator: \.isWhitespace).map(String.init)
        if tokens.count > 1 {
            return tokens.count <= 3 && tokens.allSatisfy(looksLikeBlobToken)
        }
        return looksLikeBlobToken(value)
    }

    private func looksLikeBlobToken(_ value: String) -> Bool {
        guard value.count >= 16 else { return false }
        guard !value.lowercased().hasSuffix(".pirate"), !value.lowercased().hasSuffix(".heaven") else {
            return false
        }
        let allowedCount = value.filter { $0.isLetter || $0.isNumber || "-_=+/.".contains($0) }.count
        guard allowedCount == value.count else { return false }
        let alphanumericCount = value.filter { $0.isLetter || $0.isNumber }.count
        return Double(alphanumericCount) / Double(value.count) >= 0.85
    }

    private static func xmtpEnvironment() -> XMTPEnvironment {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "XMTP_ENVIRONMENT") as? String)
            ?? ProcessInfo.processInfo.environment["XMTP_ENVIRONMENT"]
            ?? "production"
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "dev", "development":
            return .dev
        case "local":
            return .local
        default:
            return .production
        }
    }
    #endif
}

private extension Array {
    func asyncCompactMap<T>(_ transform: (Element) async -> T?) async -> [T] {
        var values: [T] = []
        for element in self {
            if let value = await transform(element) {
                values.append(value)
            }
        }
        return values
    }
}
