import Foundation

struct NotificationSummary: Codable {
    let openTaskCount: Int?
    let unreadActivityCount: Int?
    let hasUnread: Bool?

    enum CodingKeys: String, CodingKey {
        case openTaskCount = "open_task_count"
        case unreadActivityCount = "unread_activity_count"
        case hasUnread = "has_unread"
    }
}

struct NotificationTasksResponse: Codable {
    let items: [UserTask]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct UserTask: Codable, Identifiable {
    let id: String
    let objectType: String?
    let userId: String?
    let type: String?
    let subjectType: String?
    let subject: String?
    let status: String?
    let priority: Int?
    let payload: [String: JSONValue]?
    let resolvedAt: String?
    let dismissedAt: String?
    let created: String?

    enum CodingKeys: String, CodingKey {
        case id
        case objectType = "object"
        case userId = "user"
        case type
        case subjectType = "subject_type"
        case subject, status, priority, payload
        case resolvedAt = "resolved_at"
        case dismissedAt = "dismissed_at"
        case created
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = container.decodeLossyStringIfPresent(forKey: .id) ?? UUID().uuidString
        self.objectType = container.decodeLossyStringIfPresent(forKey: .objectType)
        self.userId = container.decodeLossyStringIfPresent(forKey: .userId)
        self.type = container.decodeLossyStringIfPresent(forKey: .type)
        self.subjectType = container.decodeLossyStringIfPresent(forKey: .subjectType)
        self.subject = container.decodeLossyStringIfPresent(forKey: .subject)
        self.status = container.decodeLossyStringIfPresent(forKey: .status)
        self.priority = container.decodeLossyIntIfPresent(forKey: .priority)
        self.payload = try? container.decodeIfPresent([String: JSONValue].self, forKey: .payload)
        self.resolvedAt = container.decodeLossyStringIfPresent(forKey: .resolvedAt)
        self.dismissedAt = container.decodeLossyStringIfPresent(forKey: .dismissedAt)
        self.created = container.decodeLossyStringIfPresent(forKey: .created)
    }
}

struct NotificationFeedResponse: Codable {
    let items: [NotificationFeedItem]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct NotificationFeedItem: Codable, Identifiable {
    let id: String
    let event: NotificationEvent?
    let receipt: NotificationReceipt?

    enum CodingKeys: String, CodingKey {
        case id, event, receipt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.event = try? container.decodeIfPresent(NotificationEvent.self, forKey: .event)
        self.receipt = try? container.decodeIfPresent(NotificationReceipt.self, forKey: .receipt)
        self.id = container.decodeLossyStringIfPresent(forKey: .id)
            ?? receipt?.id
            ?? event?.id
            ?? UUID().uuidString
    }
}

struct NotificationEvent: Codable {
    let id: String?
    let type: String?
    let actorUserId: String?
    let subjectType: String?
    let subject: String?
    let objectType: String?
    let payload: [String: JSONValue]?
    let created: String?

    enum CodingKeys: String, CodingKey {
        case id, type
        case actorUserId = "actor_user_id"
        case subjectType = "subject_type"
        case subject
        case objectType = "object_type"
        case payload, created
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = container.decodeLossyStringIfPresent(forKey: .id)
        self.type = container.decodeLossyStringIfPresent(forKey: .type)
        self.actorUserId = container.decodeLossyStringIfPresent(forKey: .actorUserId)
        self.subjectType = container.decodeLossyStringIfPresent(forKey: .subjectType)
        self.subject = container.decodeLossyStringIfPresent(forKey: .subject)
        self.objectType = container.decodeLossyStringIfPresent(forKey: .objectType)
        self.payload = try? container.decodeIfPresent([String: JSONValue].self, forKey: .payload)
        self.created = container.decodeLossyStringIfPresent(forKey: .created)
    }
}

struct NotificationReceipt: Codable {
    let id: String?
    let recipientUserId: String?
    let seenAt: String?
    let readAt: String?
    let created: String?

    enum CodingKeys: String, CodingKey {
        case id
        case recipientUserId = "recipient_user_id"
        case seenAt = "seen_at"
        case readAt = "read_at"
        case created
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = container.decodeLossyStringIfPresent(forKey: .id)
        self.recipientUserId = container.decodeLossyStringIfPresent(forKey: .recipientUserId)
        self.seenAt = container.decodeLossyStringIfPresent(forKey: .seenAt)
        self.readAt = container.decodeLossyStringIfPresent(forKey: .readAt)
        self.created = container.decodeLossyStringIfPresent(forKey: .created)
    }
}
