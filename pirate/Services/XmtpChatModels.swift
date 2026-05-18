import Foundation

enum XmtpConversationKind: String, Codable, Hashable {
    case dm
    case group
}

struct XmtpConversationItem: Identifiable, Hashable {
    let id: String
    let kind: XmtpConversationKind
    let displayName: String
    let avatarRef: String?
    let lastMessage: String
    let lastMessageDate: Date?
    let subtitle: String?
    let peerAddress: String?
    let peerInboxId: String?
}

struct XmtpChatMessage: Identifiable, Hashable {
    let id: String
    let senderAddress: String
    let senderInboxId: String
    let text: String
    let sentAt: Date
    let isFromMe: Bool
}

struct XmtpResolvedPeerIdentity: Hashable {
    let displayName: String
    let avatarRef: String?
}
