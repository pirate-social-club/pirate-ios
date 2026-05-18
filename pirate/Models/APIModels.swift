import Foundation

enum JSONValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .bool(let value): return value ? "true" : "false"
        case .object, .array, .null: return nil
        }
    }
}

extension KeyedDecodingContainer {
    func decodeLossyStringIfPresent(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value ? "true" : "false" }
        return nil
    }

    func decodeLossyIntIfPresent(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return Int(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Int(value) }
        return nil
    }

    func decodeLossyDoubleIfPresent(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }

    func decodeLossyBoolIfPresent(forKey key: Key) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            if value == "true" { return true }
            if value == "false" { return false }
        }
        return nil
    }
}

struct SessionExchangeResponse: Codable {
    let accessToken: String
    let user: User
    let profile: Profile
    let onboarding: OnboardingStatus
    let walletAttachments: [WalletAttachmentSummary]

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case user, profile, onboarding
        case walletAttachments = "wallet_attachments"
    }
}

struct User: Codable, Identifiable {
    let userId: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case id
        case createdAt = "created_at"
        case created
    }

    var id: String { userId }

    init(userId: String, createdAt: String? = nil) {
        self.userId = userId
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = container.decodeLossyStringIfPresent(forKey: .userId)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
            ?? ""
        self.createdAt = container.decodeLossyStringIfPresent(forKey: .createdAt)
            ?? container.decodeLossyStringIfPresent(forKey: .created)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

struct Profile: Codable {
    let userId: String
    let displayName: String?
    let bio: String?
    let avatarRef: String?
    let coverRef: String?
    let globalHandle: GlobalHandle?
    let primaryPublicHandle: LinkedHandle?
    let linkedHandles: [LinkedHandle]?
    let primaryWalletAddress: String?
    let xmtpInbox: String?
    let nationalityBadgeCountry: String?
    let followerCount: Int?
    let followingCount: Int?
    let preferredLocale: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
        case bio
        case avatarRef = "avatar_ref"
        case coverRef = "cover_ref"
        case globalHandle = "global_handle"
        case primaryPublicHandle = "primary_public_handle"
        case linkedHandles = "linked_handles"
        case primaryWalletAddress = "primary_wallet_address"
        case xmtpInbox = "xmtp_inbox"
        case nationalityBadgeCountry = "nationality_badge_country"
        case followerCount = "follower_count"
        case followingCount = "following_count"
        case preferredLocale = "preferred_locale"
        case id
        case created
        case createdAt = "created_at"
    }

    var avatarURL: URL? {
        guard let ref = avatarRef else { return nil }
        return URL(string: ref)
    }

    var coverURL: URL? {
        guard let ref = coverRef else { return nil }
        return URL(string: ref)
    }

    init(
        userId: String,
        displayName: String? = nil,
        bio: String? = nil,
        avatarRef: String? = nil,
        coverRef: String? = nil,
        globalHandle: GlobalHandle? = nil,
        primaryPublicHandle: LinkedHandle? = nil,
        linkedHandles: [LinkedHandle]? = nil,
        primaryWalletAddress: String? = nil,
        xmtpInbox: String? = nil,
        nationalityBadgeCountry: String? = nil,
        followerCount: Int? = nil,
        followingCount: Int? = nil,
        preferredLocale: String? = nil
    ) {
        self.userId = userId
        self.displayName = displayName
        self.bio = bio
        self.avatarRef = avatarRef
        self.coverRef = coverRef
        self.globalHandle = globalHandle
        self.primaryPublicHandle = primaryPublicHandle
        self.linkedHandles = linkedHandles
        self.primaryWalletAddress = primaryWalletAddress
        self.xmtpInbox = xmtpInbox
        self.nationalityBadgeCountry = nationalityBadgeCountry
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.preferredLocale = preferredLocale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = container.decodeLossyStringIfPresent(forKey: .userId)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
            ?? ""
        self.displayName = container.decodeLossyStringIfPresent(forKey: .displayName)
        self.bio = container.decodeLossyStringIfPresent(forKey: .bio)
        self.avatarRef = container.decodeLossyStringIfPresent(forKey: .avatarRef)
        self.coverRef = container.decodeLossyStringIfPresent(forKey: .coverRef)
        self.globalHandle = try? container.decodeIfPresent(GlobalHandle.self, forKey: .globalHandle)
        self.primaryPublicHandle = try? container.decodeIfPresent(LinkedHandle.self, forKey: .primaryPublicHandle)
        self.linkedHandles = (try? container.decodeIfPresent([LinkedHandle].self, forKey: .linkedHandles)) ?? []
        self.primaryWalletAddress = container.decodeLossyStringIfPresent(forKey: .primaryWalletAddress)
        self.xmtpInbox = container.decodeLossyStringIfPresent(forKey: .xmtpInbox)
        self.nationalityBadgeCountry = container.decodeLossyStringIfPresent(forKey: .nationalityBadgeCountry)
        self.followerCount = container.decodeLossyIntIfPresent(forKey: .followerCount)
        self.followingCount = container.decodeLossyIntIfPresent(forKey: .followingCount)
        self.preferredLocale = container.decodeLossyStringIfPresent(forKey: .preferredLocale)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(avatarRef, forKey: .avatarRef)
        try container.encodeIfPresent(coverRef, forKey: .coverRef)
        try container.encodeIfPresent(globalHandle, forKey: .globalHandle)
        try container.encodeIfPresent(primaryPublicHandle, forKey: .primaryPublicHandle)
        try container.encodeIfPresent(linkedHandles, forKey: .linkedHandles)
        try container.encodeIfPresent(primaryWalletAddress, forKey: .primaryWalletAddress)
        try container.encodeIfPresent(xmtpInbox, forKey: .xmtpInbox)
        try container.encodeIfPresent(nationalityBadgeCountry, forKey: .nationalityBadgeCountry)
        try container.encodeIfPresent(followerCount, forKey: .followerCount)
        try container.encodeIfPresent(followingCount, forKey: .followingCount)
        try container.encodeIfPresent(preferredLocale, forKey: .preferredLocale)
    }
}

struct XmtpInboxUpdateInput: Encodable {
    let xmtpInbox: String

    enum CodingKeys: String, CodingKey {
        case xmtpInbox = "xmtp_inbox"
    }
}

struct ProfileUpdateInput: Encodable {
    var displayName: String? = nil
    var avatarRef: String? = nil
    var avatarSource: String? = nil
    var coverRef: String? = nil
    var coverSource: String? = nil
    var bio: String? = nil
    var clearBio = false
    var bioSource: String? = nil
    var preferredLocale: String? = nil

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case avatarRef = "avatar_ref"
        case avatarSource = "avatar_source"
        case coverRef = "cover_ref"
        case coverSource = "cover_source"
        case bio
        case bioSource = "bio_source"
        case preferredLocale = "preferred_locale"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(avatarRef, forKey: .avatarRef)
        try container.encodeIfPresent(avatarSource, forKey: .avatarSource)
        try container.encodeIfPresent(coverRef, forKey: .coverRef)
        try container.encodeIfPresent(coverSource, forKey: .coverSource)
        if clearBio {
            try container.encodeNil(forKey: .bio)
        } else {
            try container.encodeIfPresent(bio, forKey: .bio)
        }
        try container.encodeIfPresent(bioSource, forKey: .bioSource)
        try container.encodeIfPresent(preferredLocale, forKey: .preferredLocale)
    }
}

struct ProfileMediaUploadResponse: Codable {
    let kind: String
    let mediaRef: String
    let ipfsCid: String?
    let mimeType: String
    let sizeBytes: Int?
    let storageBucket: String?
    let storageObjectKey: String?

    enum CodingKeys: String, CodingKey {
        case kind
        case mediaRef = "media_ref"
        case ipfsCid = "ipfs_cid"
        case mimeType = "mime_type"
        case sizeBytes = "size_bytes"
        case storageBucket = "storage_bucket"
        case storageObjectKey = "storage_object_key"
    }
}

struct RenameHandleRequest: Encodable {
    let desiredLabel: String

    enum CodingKeys: String, CodingKey {
        case desiredLabel = "desired_label"
    }
}

struct RenameHandleResponse: Codable {
    let globalHandleId: String?
    let label: String
    let tier: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case globalHandleId = "global_handle_id"
        case label
        case tier
        case status
    }
}

struct GlobalHandle: Codable {
    let id: String?
    let label: String
    let tier: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id, label, tier, status
    }
}

struct LinkedHandle: Codable, Identifiable {
    let linkedHandle: String
    let label: String
    let kind: String?
    let verificationState: String?
    let metadata: [String: JSONValue]?

    enum CodingKeys: String, CodingKey {
        case linkedHandle = "linked_handle"
        case label, kind
        case verificationState = "verification_state"
        case metadata
    }

    var id: String { linkedHandle }
}

struct WalletAttachmentSummary: Codable, Identifiable {
    let walletAttachmentId: String
    let chainNamespace: String?
    let walletAddress: String
    let isPrimary: Bool?
    let chainId: String?

    enum CodingKeys: String, CodingKey {
        case walletAttachmentId = "wallet_attachment_id"
        case walletAttachment = "wallet_attachment"
        case id
        case chainNamespace = "chain_namespace"
        case walletAddress = "wallet_address"
        case isPrimary = "is_primary"
        case chainId = "chain_id"
    }

    var id: String { walletAttachmentId }

    init(
        walletAttachmentId: String,
        chainNamespace: String? = nil,
        walletAddress: String,
        isPrimary: Bool? = nil,
        chainId: String? = nil
    ) {
        self.walletAttachmentId = walletAttachmentId
        self.chainNamespace = chainNamespace
        self.walletAddress = walletAddress
        self.isPrimary = isPrimary
        self.chainId = chainId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let walletAddress = container.decodeLossyStringIfPresent(forKey: .walletAddress) ?? ""
        self.walletAttachmentId = container.decodeLossyStringIfPresent(forKey: .walletAttachmentId)
            ?? container.decodeLossyStringIfPresent(forKey: .walletAttachment)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
            ?? walletAddress
        self.chainNamespace = container.decodeLossyStringIfPresent(forKey: .chainNamespace)
        self.walletAddress = walletAddress
        self.isPrimary = container.decodeLossyBoolIfPresent(forKey: .isPrimary)
        self.chainId = container.decodeLossyStringIfPresent(forKey: .chainId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(walletAttachmentId, forKey: .walletAttachmentId)
        try container.encodeIfPresent(chainNamespace, forKey: .chainNamespace)
        try container.encode(walletAddress, forKey: .walletAddress)
        try container.encodeIfPresent(isPrimary, forKey: .isPrimary)
        try container.encodeIfPresent(chainId, forKey: .chainId)
    }
}

struct OnboardingStatus: Codable {
    let redditVerificationStatus: String?
    let redditImportStatus: String?
    let cleanupRenameAvailable: Bool?
    let onboardingDismissedAt: String?
    let uniqueHumanVerificationStatus: String?

    enum CodingKeys: String, CodingKey {
        case redditVerificationStatus = "reddit_verification_status"
        case redditImportStatus = "reddit_import_status"
        case cleanupRenameAvailable = "cleanup_rename_available"
        case onboardingDismissedAt = "onboarding_dismissed_at"
        case uniqueHumanVerificationStatus = "unique_human_verification_status"
    }

    init(
        redditVerificationStatus: String? = nil,
        redditImportStatus: String? = nil,
        cleanupRenameAvailable: Bool? = nil,
        onboardingDismissedAt: String? = nil,
        uniqueHumanVerificationStatus: String? = nil
    ) {
        self.redditVerificationStatus = redditVerificationStatus
        self.redditImportStatus = redditImportStatus
        self.cleanupRenameAvailable = cleanupRenameAvailable
        self.onboardingDismissedAt = onboardingDismissedAt
        self.uniqueHumanVerificationStatus = uniqueHumanVerificationStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.redditVerificationStatus = container.decodeLossyStringIfPresent(forKey: .redditVerificationStatus)
        self.redditImportStatus = container.decodeLossyStringIfPresent(forKey: .redditImportStatus)
        self.cleanupRenameAvailable = container.decodeLossyBoolIfPresent(forKey: .cleanupRenameAvailable)
        self.onboardingDismissedAt = container.decodeLossyStringIfPresent(forKey: .onboardingDismissedAt)
        self.uniqueHumanVerificationStatus = container.decodeLossyStringIfPresent(forKey: .uniqueHumanVerificationStatus)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(redditVerificationStatus, forKey: .redditVerificationStatus)
        try container.encodeIfPresent(redditImportStatus, forKey: .redditImportStatus)
        try container.encodeIfPresent(cleanupRenameAvailable, forKey: .cleanupRenameAvailable)
        try container.encodeIfPresent(onboardingDismissedAt, forKey: .onboardingDismissedAt)
        try container.encodeIfPresent(uniqueHumanVerificationStatus, forKey: .uniqueHumanVerificationStatus)
    }
}

struct Community: Codable, Identifiable {
    let communityId: String
    let displayName: String
    let routeSlug: String?
    let namespaceVerificationId: String?
    let pendingNamespaceVerificationSessionId: String?
    let description: String?
    let membershipMode: String?
    let allowAnonymousIdentity: Bool?
    let allowQualifiersOnAnonymousPosts: Bool?
    let anonymousIdentityScope: String?
    let allowedDisclosedQualifiers: [String]?
    let gateRules: [CommunityGateRule]?
    let memberCount: Int?
    let followerCount: Int?
    let avatarRef: String?
    let bannerRef: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case communityId = "community_id"
        case id
        case community
        case displayName = "display_name"
        case routeSlug = "route_slug"
        case namespaceVerificationId = "namespace_verification_id"
        case pendingNamespaceVerificationSessionId = "pending_namespace_verification_session_id"
        case description
        case membershipMode = "membership_mode"
        case allowAnonymousIdentity = "allow_anonymous_identity"
        case allowQualifiersOnAnonymousPosts = "allow_qualifiers_on_anonymous_posts"
        case anonymousIdentityScope = "anonymous_identity_scope"
        case allowedDisclosedQualifiers = "allowed_disclosed_qualifiers"
        case gateRules = "gate_rules"
        case memberCount = "member_count"
        case followerCount = "follower_count"
        case avatarRef = "avatar_ref"
        case bannerRef = "banner_ref"
        case createdAt = "created_at"
        case created
    }

    var id: String { communityId }

    var avatarURL: URL? {
        guard let ref = avatarRef else { return nil }
        return URL(string: ref)
    }

    var bannerURL: URL? {
        guard let ref = bannerRef else { return nil }
        return URL(string: ref)
    }

    init(
        communityId: String,
        displayName: String,
        routeSlug: String? = nil,
        namespaceVerificationId: String? = nil,
        pendingNamespaceVerificationSessionId: String? = nil,
        description: String? = nil,
        membershipMode: String? = nil,
        allowAnonymousIdentity: Bool? = nil,
        allowQualifiersOnAnonymousPosts: Bool? = nil,
        anonymousIdentityScope: String? = nil,
        allowedDisclosedQualifiers: [String]? = nil,
        gateRules: [CommunityGateRule]? = nil,
        memberCount: Int? = nil,
        followerCount: Int? = nil,
        avatarRef: String? = nil,
        bannerRef: String? = nil,
        createdAt: String? = nil
    ) {
        self.communityId = communityId
        self.displayName = displayName
        self.routeSlug = routeSlug
        self.namespaceVerificationId = namespaceVerificationId
        self.pendingNamespaceVerificationSessionId = pendingNamespaceVerificationSessionId
        self.description = description
        self.membershipMode = membershipMode
        self.allowAnonymousIdentity = allowAnonymousIdentity
        self.allowQualifiersOnAnonymousPosts = allowQualifiersOnAnonymousPosts
        self.anonymousIdentityScope = anonymousIdentityScope
        self.allowedDisclosedQualifiers = allowedDisclosedQualifiers
        self.gateRules = gateRules
        self.memberCount = memberCount
        self.followerCount = followerCount
        self.avatarRef = avatarRef
        self.bannerRef = bannerRef
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.communityId = container.decodeLossyStringIfPresent(forKey: .communityId)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
            ?? container.decodeLossyStringIfPresent(forKey: .community)
            ?? ""
        self.displayName = container.decodeLossyStringIfPresent(forKey: .displayName) ?? "Community"
        self.routeSlug = container.decodeLossyStringIfPresent(forKey: .routeSlug)
        self.namespaceVerificationId = container.decodeLossyStringIfPresent(forKey: .namespaceVerificationId)
        self.pendingNamespaceVerificationSessionId = container.decodeLossyStringIfPresent(forKey: .pendingNamespaceVerificationSessionId)
        self.description = container.decodeLossyStringIfPresent(forKey: .description)
        self.membershipMode = container.decodeLossyStringIfPresent(forKey: .membershipMode)
        self.allowAnonymousIdentity = container.decodeLossyBoolIfPresent(forKey: .allowAnonymousIdentity)
        self.allowQualifiersOnAnonymousPosts = container.decodeLossyBoolIfPresent(forKey: .allowQualifiersOnAnonymousPosts)
        self.anonymousIdentityScope = container.decodeLossyStringIfPresent(forKey: .anonymousIdentityScope)
        self.allowedDisclosedQualifiers = (try? container.decodeIfPresent([String].self, forKey: .allowedDisclosedQualifiers)) ?? []
        self.gateRules = (try? container.decodeIfPresent([CommunityGateRule].self, forKey: .gateRules)) ?? []
        self.memberCount = container.decodeLossyIntIfPresent(forKey: .memberCount)
        self.followerCount = container.decodeLossyIntIfPresent(forKey: .followerCount)
        self.avatarRef = container.decodeLossyStringIfPresent(forKey: .avatarRef)
        self.bannerRef = container.decodeLossyStringIfPresent(forKey: .bannerRef)
        self.createdAt = container.decodeLossyStringIfPresent(forKey: .createdAt)
            ?? container.decodeLossyStringIfPresent(forKey: .created)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(communityId, forKey: .communityId)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(routeSlug, forKey: .routeSlug)
        try container.encodeIfPresent(namespaceVerificationId, forKey: .namespaceVerificationId)
        try container.encodeIfPresent(pendingNamespaceVerificationSessionId, forKey: .pendingNamespaceVerificationSessionId)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(membershipMode, forKey: .membershipMode)
        try container.encodeIfPresent(allowAnonymousIdentity, forKey: .allowAnonymousIdentity)
        try container.encodeIfPresent(allowQualifiersOnAnonymousPosts, forKey: .allowQualifiersOnAnonymousPosts)
        try container.encodeIfPresent(anonymousIdentityScope, forKey: .anonymousIdentityScope)
        try container.encodeIfPresent(allowedDisclosedQualifiers, forKey: .allowedDisclosedQualifiers)
        try container.encodeIfPresent(gateRules, forKey: .gateRules)
        try container.encodeIfPresent(memberCount, forKey: .memberCount)
        try container.encodeIfPresent(followerCount, forKey: .followerCount)
        try container.encodeIfPresent(avatarRef, forKey: .avatarRef)
        try container.encodeIfPresent(bannerRef, forKey: .bannerRef)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

struct CommunityPreview: Codable {
    let community: Community
    let humanVerificationLane: String?
    let referenceLinks: [CommunityReferenceLink]?
    let membershipGateSummaries: [MembershipGateSummary]?
    let rules: [CommunityRule]?
    let owner: CommunityRoleHolder?
    let moderators: [CommunityRoleHolder]
    let donationPolicyMode: String?
    let donationPartner: CommunityDonationPartner?
    let flairPolicy: CommunityFlairPolicy?
    let viewerMembershipStatus: String?
    let viewerFollowing: Bool?

    enum CodingKeys: String, CodingKey {
        case community
        case communityId = "community_id"
        case id
        case displayName = "display_name"
        case routeSlug = "route_slug"
        case description
        case avatarRef = "avatar_ref"
        case bannerRef = "banner_ref"
        case membershipMode = "membership_mode"
        case allowAnonymousIdentity = "allow_anonymous_identity"
        case allowQualifiersOnAnonymousPosts = "allow_qualifiers_on_anonymous_posts"
        case anonymousIdentityScope = "anonymous_identity_scope"
        case allowedDisclosedQualifiers = "allowed_disclosed_qualifiers"
        case gateRules = "gate_rules"
        case memberCount = "member_count"
        case followerCount = "follower_count"
        case namespaceVerificationId = "namespace_verification_id"
        case pendingNamespaceVerificationSessionId = "pending_namespace_verification_session_id"
        case createdAt = "created_at"
        case created
        case humanVerificationLane = "human_verification_lane"
        case referenceLinks = "reference_links"
        case membershipGateSummaries = "membership_gate_summaries"
        case rules
        case owner
        case moderators
        case donationPolicyMode = "donation_policy_mode"
        case donationPartner = "donation_partner"
        case flairPolicy = "flair_policy"
        case viewerMembershipStatus = "viewer_membership_status"
        case viewerFollowing = "viewer_following"
    }

    init(
        community: Community,
        humanVerificationLane: String? = nil,
        referenceLinks: [CommunityReferenceLink]? = nil,
        membershipGateSummaries: [MembershipGateSummary]? = nil,
        rules: [CommunityRule]? = nil,
        owner: CommunityRoleHolder? = nil,
        moderators: [CommunityRoleHolder] = [],
        donationPolicyMode: String? = nil,
        donationPartner: CommunityDonationPartner? = nil,
        flairPolicy: CommunityFlairPolicy? = nil,
        viewerMembershipStatus: String? = nil,
        viewerFollowing: Bool? = nil
    ) {
        self.community = community
        self.humanVerificationLane = humanVerificationLane
        self.referenceLinks = referenceLinks
        self.membershipGateSummaries = membershipGateSummaries
        self.rules = rules
        self.owner = owner
        self.moderators = moderators
        self.donationPolicyMode = donationPolicyMode
        self.donationPartner = donationPartner
        self.flairPolicy = flairPolicy
        self.viewerMembershipStatus = viewerMembershipStatus
        self.viewerFollowing = viewerFollowing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let nestedCommunity = try? container.decodeIfPresent(Community.self, forKey: .community) {
            self.community = nestedCommunity
        } else {
            let communityId = container.decodeLossyStringIfPresent(forKey: .communityId)
                ?? container.decodeLossyStringIfPresent(forKey: .id)
                ?? ""
            self.community = Community(
                communityId: communityId,
                displayName: container.decodeLossyStringIfPresent(forKey: .displayName) ?? "Community",
                routeSlug: container.decodeLossyStringIfPresent(forKey: .routeSlug),
                namespaceVerificationId: container.decodeLossyStringIfPresent(forKey: .namespaceVerificationId),
                pendingNamespaceVerificationSessionId: container.decodeLossyStringIfPresent(forKey: .pendingNamespaceVerificationSessionId),
                description: container.decodeLossyStringIfPresent(forKey: .description),
                membershipMode: container.decodeLossyStringIfPresent(forKey: .membershipMode),
                allowAnonymousIdentity: container.decodeLossyBoolIfPresent(forKey: .allowAnonymousIdentity),
                allowQualifiersOnAnonymousPosts: container.decodeLossyBoolIfPresent(forKey: .allowQualifiersOnAnonymousPosts),
                anonymousIdentityScope: container.decodeLossyStringIfPresent(forKey: .anonymousIdentityScope),
                allowedDisclosedQualifiers: (try? container.decodeIfPresent([String].self, forKey: .allowedDisclosedQualifiers)) ?? [],
                gateRules: (try? container.decodeIfPresent([CommunityGateRule].self, forKey: .gateRules)) ?? [],
                memberCount: container.decodeLossyIntIfPresent(forKey: .memberCount),
                followerCount: container.decodeLossyIntIfPresent(forKey: .followerCount),
                avatarRef: container.decodeLossyStringIfPresent(forKey: .avatarRef),
                bannerRef: container.decodeLossyStringIfPresent(forKey: .bannerRef),
                createdAt: container.decodeLossyStringIfPresent(forKey: .createdAt)
                    ?? container.decodeLossyStringIfPresent(forKey: .created)
            )
        }
        self.humanVerificationLane = container.decodeLossyStringIfPresent(forKey: .humanVerificationLane)
        self.referenceLinks = (try? container.decodeIfPresent([CommunityReferenceLink].self, forKey: .referenceLinks)) ?? []
        self.membershipGateSummaries = (try? container.decodeIfPresent([MembershipGateSummary].self, forKey: .membershipGateSummaries)) ?? []
        self.rules = (try? container.decodeIfPresent([CommunityRule].self, forKey: .rules)) ?? []
        self.owner = try? container.decodeIfPresent(CommunityRoleHolder.self, forKey: .owner)
        self.moderators = (try? container.decodeIfPresent([CommunityRoleHolder].self, forKey: .moderators)) ?? []
        self.donationPolicyMode = container.decodeLossyStringIfPresent(forKey: .donationPolicyMode)
        self.donationPartner = try? container.decodeIfPresent(CommunityDonationPartner.self, forKey: .donationPartner)
        self.flairPolicy = try? container.decodeIfPresent(CommunityFlairPolicy.self, forKey: .flairPolicy)
        self.viewerMembershipStatus = container.decodeLossyStringIfPresent(forKey: .viewerMembershipStatus)
        self.viewerFollowing = container.decodeLossyBoolIfPresent(forKey: .viewerFollowing)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(community, forKey: .community)
        try container.encodeIfPresent(humanVerificationLane, forKey: .humanVerificationLane)
        try container.encodeIfPresent(referenceLinks, forKey: .referenceLinks)
        try container.encodeIfPresent(membershipGateSummaries, forKey: .membershipGateSummaries)
        try container.encodeIfPresent(rules, forKey: .rules)
        try container.encodeIfPresent(owner, forKey: .owner)
        try container.encode(moderators, forKey: .moderators)
        try container.encodeIfPresent(donationPolicyMode, forKey: .donationPolicyMode)
        try container.encodeIfPresent(donationPartner, forKey: .donationPartner)
        try container.encodeIfPresent(flairPolicy, forKey: .flairPolicy)
        try container.encodeIfPresent(viewerMembershipStatus, forKey: .viewerMembershipStatus)
        try container.encodeIfPresent(viewerFollowing, forKey: .viewerFollowing)
    }
}

struct CommunityGateRule: Codable {
    let scope: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case scope, status
    }
}

struct CommunityRule: Codable, Identifiable {
    let ruleId: String
    let title: String
    let body: String?
    let position: Int?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case ruleId = "rule_id"
        case id
        case title, body, position, status
    }

    var id: String { ruleId }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ruleId = container.decodeLossyStringIfPresent(forKey: .ruleId)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
            ?? UUID().uuidString
        self.title = container.decodeLossyStringIfPresent(forKey: .title) ?? "Rule"
        self.body = container.decodeLossyStringIfPresent(forKey: .body)
        self.position = container.decodeLossyIntIfPresent(forKey: .position)
        self.status = container.decodeLossyStringIfPresent(forKey: .status)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ruleId, forKey: .ruleId)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(position, forKey: .position)
        try container.encodeIfPresent(status, forKey: .status)
    }
}

struct CommunityReferenceLink: Codable, Identifiable {
    let communityReferenceLinkId: String?
    let platform: String?
    let label: String?
    let url: String?
    let linkStatus: String?
    let metadata: CommunityReferenceLinkMetadata?
    let position: Int?
    let verified: Bool?

    enum CodingKeys: String, CodingKey {
        case communityReferenceLinkId = "community_reference_link"
        case id
        case platform, label, url
        case linkStatus = "link_status"
        case metadata
        case position
        case verified
    }

    var id: String {
        communityReferenceLinkId ?? url ?? label ?? UUID().uuidString
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.communityReferenceLinkId = container.decodeLossyStringIfPresent(forKey: .communityReferenceLinkId)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
        self.platform = container.decodeLossyStringIfPresent(forKey: .platform)
        self.label = container.decodeLossyStringIfPresent(forKey: .label)
        self.url = container.decodeLossyStringIfPresent(forKey: .url)
        self.linkStatus = container.decodeLossyStringIfPresent(forKey: .linkStatus)
        self.metadata = try? container.decodeIfPresent(CommunityReferenceLinkMetadata.self, forKey: .metadata)
        self.position = container.decodeLossyIntIfPresent(forKey: .position)
        self.verified = container.decodeLossyBoolIfPresent(forKey: .verified)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(communityReferenceLinkId, forKey: .communityReferenceLinkId)
        try container.encodeIfPresent(platform, forKey: .platform)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(linkStatus, forKey: .linkStatus)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(position, forKey: .position)
        try container.encodeIfPresent(verified, forKey: .verified)
    }
}

struct CommunityReferenceLinkMetadata: Codable {
    let displayName: String?
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case imageURL = "image_url"
    }
}

struct CommunityRoleHolder: Codable, Identifiable {
    let user: String
    let displayName: String?
    let handle: String?
    let avatarRef: String?
    let nationalityBadgeCountry: String?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case user
        case displayName = "display_name"
        case handle
        case avatarRef = "avatar_ref"
        case nationalityBadgeCountry = "nationality_badge_country"
        case role
    }

    var id: String { user }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.user = container.decodeLossyStringIfPresent(forKey: .user) ?? UUID().uuidString
        self.displayName = container.decodeLossyStringIfPresent(forKey: .displayName)
        self.handle = container.decodeLossyStringIfPresent(forKey: .handle)
        self.avatarRef = container.decodeLossyStringIfPresent(forKey: .avatarRef)
        self.nationalityBadgeCountry = container.decodeLossyStringIfPresent(forKey: .nationalityBadgeCountry)
        self.role = container.decodeLossyStringIfPresent(forKey: .role)
    }
}

struct CommunityDonationPartner: Codable {
    let displayName: String?
    let imageURL: String?
    let providerPartnerRef: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case imageURL = "image_url"
        case providerPartnerRef = "provider_partner_ref"
    }
}

struct CommunityFlairPolicy: Codable {
    let flairEnabled: Bool?
    let definitions: [CommunityFlairDefinition]

    enum CodingKeys: String, CodingKey {
        case flairEnabled = "flair_enabled"
        case definitions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.flairEnabled = container.decodeLossyBoolIfPresent(forKey: .flairEnabled)
        self.definitions = (try? container.decodeIfPresent([CommunityFlairDefinition].self, forKey: .definitions)) ?? []
    }
}

struct CommunityFlairDefinition: Codable, Identifiable {
    let flairId: String
    let label: String?
    let colorToken: String?
    let status: String?
    let position: Int?

    enum CodingKeys: String, CodingKey {
        case flairId = "flair_id"
        case id
        case label
        case colorToken = "color_token"
        case status
        case position
    }

    var id: String { flairId }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.flairId = container.decodeLossyStringIfPresent(forKey: .flairId)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
            ?? UUID().uuidString
        self.label = container.decodeLossyStringIfPresent(forKey: .label)
        self.colorToken = container.decodeLossyStringIfPresent(forKey: .colorToken)
        self.status = container.decodeLossyStringIfPresent(forKey: .status)
        self.position = container.decodeLossyIntIfPresent(forKey: .position)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(flairId, forKey: .flairId)
        try container.encodeIfPresent(label, forKey: .label)
        try container.encodeIfPresent(colorToken, forKey: .colorToken)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(position, forKey: .position)
    }
}

struct MembershipGateSummary: Codable {
    let gateType: String?
    let acceptedProviders: [String]?
    let requiredValue: String?
    let requiredValues: [String]?
    let excludedValues: [String]?
    let requiredMinimumAge: Int?
    let minimumScore: Double?
    let chainNamespace: String?
    let contractAddress: String?
    let assetCategory: String?
    let assetFilterLabel: String?
    let minQuantity: Int?

    enum CodingKeys: String, CodingKey {
        case gateType = "gate_type"
        case acceptedProviders = "accepted_providers"
        case requiredValue = "required_value"
        case requiredValues = "required_values"
        case excludedValues = "excluded_values"
        case requiredMinimumAge = "required_minimum_age"
        case minimumScore = "minimum_score"
        case chainNamespace = "chain_namespace"
        case contractAddress = "contract_address"
        case assetCategory = "asset_category"
        case assetFilterLabel = "asset_filter_label"
        case minQuantity = "min_quantity"
    }
}

struct JoinEligibility: Codable {
    let communityId: String
    let membershipMode: String?
    let humanVerificationLane: String?
    let joinableNow: Bool?
    let status: String?
    let membershipGateSummaries: [MembershipGateSummary]?
    let missingCapabilities: [String]?
    let suggestedVerificationProvider: String?
    let suggestedVerificationIntent: String?
    let failureReason: String?
    let walletScoreStatus: WalletScoreStatus?

    enum CodingKeys: String, CodingKey {
        case communityId = "community_id"
        case membershipMode = "membership_mode"
        case humanVerificationLane = "human_verification_lane"
        case joinableNow = "joinable_now"
        case status
        case membershipGateSummaries = "membership_gate_summaries"
        case missingCapabilities = "missing_capabilities"
        case suggestedVerificationProvider = "suggested_verification_provider"
        case suggestedVerificationIntent = "suggested_verification_intent"
        case failureReason = "failure_reason"
        case walletScoreStatus = "wallet_score_status"
    }
}

struct WalletScoreStatus: Codable {
    let currentScore: Double?
    let requiredScore: Double?
    let passingScore: JSONValue?
    let lastScoreTimestamp: String?

    enum CodingKeys: String, CodingKey {
        case currentScore = "current_score"
        case requiredScore = "required_score"
        case passingScore = "passing_score"
        case lastScoreTimestamp = "last_score_timestamp"
    }
}

struct Post: Codable, Identifiable {
    let postId: String
    let communityId: String?
    let title: String?
    let body: String?
    let caption: String?
    let linkUrl: String?
    let linkTitle: String?
    let linkDescription: String?
    let linkImage: String?
    let embeds: [JSONValue]?
    let mediaRefs: [MediaRef]?
    let postType: String?
    let status: String?
    let visibility: String?
    let authorUserId: String?
    let authorDisplayName: String?
    let authorAvatarRef: String?
    let authorIdentityMode: String?
    let authorAnonymousScope: String?
    let authorAnonymousLabel: String?
    let sourceLanguage: String?
    let translationPolicy: String?
    let accessMode: String?
    let anchorLiveRoom: String?
    let anchorLiveRoomStatus: String?
    let flairId: String?
    let score: Int?
    let upvoteCount: Int?
    let downvoteCount: Int?
    let commentCount: Int?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case id
        case post
        case communityId = "community_id"
        case community
        case title, body, caption
        case linkUrl = "link_url"
        case linkTitle = "link_title"
        case linkOgTitle = "link_og_title"
        case linkDescription = "link_description"
        case linkOgDescription = "link_og_description"
        case linkImage = "link_image"
        case linkOgImage = "link_og_image_url"
        case embeds
        case mediaRefs = "media_refs"
        case postType = "post_type"
        case status, visibility
        case authorUserId = "author_user_id"
        case authorUser = "author_user"
        case authorDisplayName = "author_display_name"
        case authorAvatarRef = "author_avatar_ref"
        case authorIdentityMode = "author_identity_mode"
        case identityMode = "identity_mode"
        case authorAnonymousScope = "author_anonymous_scope"
        case anonymousScope = "anonymous_scope"
        case authorAnonymousLabel = "author_anonymous_label"
        case anonymousLabel = "anonymous_label"
        case sourceLanguage = "source_language"
        case translationPolicy = "translation_policy"
        case accessMode = "access_mode"
        case anchorLiveRoom = "anchor_live_room"
        case anchorLiveRoomStatus = "anchor_live_room_status"
        case flairId = "flair_id"
        case labelId = "label_id"
        case score
        case upvoteCount = "upvote_count"
        case downvoteCount = "downvote_count"
        case commentCount = "comment_count"
        case createdAt = "created_at"
        case created
        case updatedAt = "updated_at"
        case updated
    }

    var id: String { postId }

    var authorAvatarURL: URL? {
        guard let ref = authorAvatarRef else { return nil }
        return URL(string: ref)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.postId = container.decodeLossyStringIfPresent(forKey: .postId)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
            ?? container.decodeLossyStringIfPresent(forKey: .post)
            ?? ""
        self.communityId = container.decodeLossyStringIfPresent(forKey: .communityId)
            ?? container.decodeLossyStringIfPresent(forKey: .community)
        self.title = container.decodeLossyStringIfPresent(forKey: .title)
        self.body = container.decodeLossyStringIfPresent(forKey: .body)
        self.caption = container.decodeLossyStringIfPresent(forKey: .caption)
        self.linkUrl = container.decodeLossyStringIfPresent(forKey: .linkUrl)
        self.linkTitle = container.decodeLossyStringIfPresent(forKey: .linkTitle)
            ?? container.decodeLossyStringIfPresent(forKey: .linkOgTitle)
        self.linkDescription = container.decodeLossyStringIfPresent(forKey: .linkDescription)
            ?? container.decodeLossyStringIfPresent(forKey: .linkOgDescription)
        self.linkImage = container.decodeLossyStringIfPresent(forKey: .linkImage)
            ?? container.decodeLossyStringIfPresent(forKey: .linkOgImage)
        self.embeds = try? container.decodeIfPresent([JSONValue].self, forKey: .embeds)
        self.mediaRefs = try? container.decodeIfPresent([MediaRef].self, forKey: .mediaRefs)
        self.postType = container.decodeLossyStringIfPresent(forKey: .postType)
        self.status = container.decodeLossyStringIfPresent(forKey: .status)
        self.visibility = container.decodeLossyStringIfPresent(forKey: .visibility)
        self.authorUserId = container.decodeLossyStringIfPresent(forKey: .authorUserId)
            ?? container.decodeLossyStringIfPresent(forKey: .authorUser)
        self.authorDisplayName = container.decodeLossyStringIfPresent(forKey: .authorDisplayName)
        self.authorAvatarRef = container.decodeLossyStringIfPresent(forKey: .authorAvatarRef)
        self.authorIdentityMode = container.decodeLossyStringIfPresent(forKey: .authorIdentityMode)
            ?? container.decodeLossyStringIfPresent(forKey: .identityMode)
        self.authorAnonymousScope = container.decodeLossyStringIfPresent(forKey: .authorAnonymousScope)
            ?? container.decodeLossyStringIfPresent(forKey: .anonymousScope)
        self.authorAnonymousLabel = container.decodeLossyStringIfPresent(forKey: .authorAnonymousLabel)
            ?? container.decodeLossyStringIfPresent(forKey: .anonymousLabel)
        self.sourceLanguage = container.decodeLossyStringIfPresent(forKey: .sourceLanguage)
        self.translationPolicy = container.decodeLossyStringIfPresent(forKey: .translationPolicy)
        self.accessMode = container.decodeLossyStringIfPresent(forKey: .accessMode)
        self.anchorLiveRoom = container.decodeLossyStringIfPresent(forKey: .anchorLiveRoom)
        self.anchorLiveRoomStatus = container.decodeLossyStringIfPresent(forKey: .anchorLiveRoomStatus)
        self.flairId = container.decodeLossyStringIfPresent(forKey: .flairId)
            ?? container.decodeLossyStringIfPresent(forKey: .labelId)
        self.score = container.decodeLossyIntIfPresent(forKey: .score)
        self.upvoteCount = container.decodeLossyIntIfPresent(forKey: .upvoteCount)
        self.downvoteCount = container.decodeLossyIntIfPresent(forKey: .downvoteCount)
        self.commentCount = container.decodeLossyIntIfPresent(forKey: .commentCount)
        self.createdAt = container.decodeLossyStringIfPresent(forKey: .createdAt)
            ?? container.decodeLossyStringIfPresent(forKey: .created)
        self.updatedAt = container.decodeLossyStringIfPresent(forKey: .updatedAt)
            ?? container.decodeLossyStringIfPresent(forKey: .updated)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(postId, forKey: .postId)
        try container.encodeIfPresent(communityId, forKey: .communityId)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(caption, forKey: .caption)
        try container.encodeIfPresent(linkUrl, forKey: .linkUrl)
        try container.encodeIfPresent(linkTitle, forKey: .linkTitle)
        try container.encodeIfPresent(linkDescription, forKey: .linkDescription)
        try container.encodeIfPresent(linkImage, forKey: .linkImage)
        try container.encodeIfPresent(embeds, forKey: .embeds)
        try container.encodeIfPresent(mediaRefs, forKey: .mediaRefs)
        try container.encodeIfPresent(postType, forKey: .postType)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(visibility, forKey: .visibility)
        try container.encodeIfPresent(authorUserId, forKey: .authorUserId)
        try container.encodeIfPresent(authorDisplayName, forKey: .authorDisplayName)
        try container.encodeIfPresent(authorAvatarRef, forKey: .authorAvatarRef)
        try container.encodeIfPresent(authorIdentityMode, forKey: .authorIdentityMode)
        try container.encodeIfPresent(authorAnonymousScope, forKey: .authorAnonymousScope)
        try container.encodeIfPresent(authorAnonymousLabel, forKey: .authorAnonymousLabel)
        try container.encodeIfPresent(sourceLanguage, forKey: .sourceLanguage)
        try container.encodeIfPresent(translationPolicy, forKey: .translationPolicy)
        try container.encodeIfPresent(accessMode, forKey: .accessMode)
        try container.encodeIfPresent(anchorLiveRoom, forKey: .anchorLiveRoom)
        try container.encodeIfPresent(anchorLiveRoomStatus, forKey: .anchorLiveRoomStatus)
        try container.encodeIfPresent(flairId, forKey: .flairId)
        try container.encodeIfPresent(score, forKey: .score)
        try container.encodeIfPresent(upvoteCount, forKey: .upvoteCount)
        try container.encodeIfPresent(downvoteCount, forKey: .downvoteCount)
        try container.encodeIfPresent(commentCount, forKey: .commentCount)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct MediaRef: Codable {
    let mediaKey: String?
    let mediaType: String?
    let mediaUrl: String?
    let storageRef: String?
    let mimeType: String?
    let sizeBytes: Int?
    let width: Int?
    let height: Int?
    let durationMs: Int?
    let posterRef: String?
    let posterMimeType: String?
    let posterWidth: Int?
    let posterHeight: Int?

    enum CodingKeys: String, CodingKey {
        case mediaKey = "media_key"
        case mediaType = "media_type"
        case mediaUrl = "media_url"
        case storageRef = "storage_ref"
        case mimeType = "mime_type"
        case sizeBytes = "size_bytes"
        case width
        case height
        case durationMs = "duration_ms"
        case posterRef = "poster_ref"
        case posterMimeType = "poster_mime_type"
        case posterWidth = "poster_width"
        case posterHeight = "poster_height"
    }

    init(
        mediaKey: String? = nil,
        mediaType: String? = nil,
        mediaUrl: String? = nil,
        storageRef: String? = nil,
        mimeType: String? = nil,
        sizeBytes: Int? = nil,
        width: Int? = nil,
        height: Int? = nil,
        durationMs: Int? = nil,
        posterRef: String? = nil,
        posterMimeType: String? = nil,
        posterWidth: Int? = nil,
        posterHeight: Int? = nil
    ) {
        self.mediaKey = mediaKey
        self.mediaType = mediaType
        self.mediaUrl = mediaUrl
        self.storageRef = storageRef
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.width = width
        self.height = height
        self.durationMs = durationMs
        self.posterRef = posterRef
        self.posterMimeType = posterMimeType
        self.posterWidth = posterWidth
        self.posterHeight = posterHeight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mediaKey = container.decodeLossyStringIfPresent(forKey: .mediaKey)
        self.mediaType = container.decodeLossyStringIfPresent(forKey: .mediaType)
        self.mediaUrl = container.decodeLossyStringIfPresent(forKey: .mediaUrl)
        self.storageRef = container.decodeLossyStringIfPresent(forKey: .storageRef)
        self.mimeType = container.decodeLossyStringIfPresent(forKey: .mimeType)
        self.sizeBytes = container.decodeLossyIntIfPresent(forKey: .sizeBytes)
        self.width = container.decodeLossyIntIfPresent(forKey: .width)
        self.height = container.decodeLossyIntIfPresent(forKey: .height)
        self.durationMs = container.decodeLossyIntIfPresent(forKey: .durationMs)
        self.posterRef = container.decodeLossyStringIfPresent(forKey: .posterRef)
        self.posterMimeType = container.decodeLossyStringIfPresent(forKey: .posterMimeType)
        self.posterWidth = container.decodeLossyIntIfPresent(forKey: .posterWidth)
        self.posterHeight = container.decodeLossyIntIfPresent(forKey: .posterHeight)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(mediaKey, forKey: .mediaKey)
        try container.encodeIfPresent(mediaType, forKey: .mediaType)
        try container.encodeIfPresent(mediaUrl, forKey: .mediaUrl)
        try container.encodeIfPresent(storageRef, forKey: .storageRef)
        try container.encodeIfPresent(mimeType, forKey: .mimeType)
        try container.encodeIfPresent(sizeBytes, forKey: .sizeBytes)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(durationMs, forKey: .durationMs)
        try container.encodeIfPresent(posterRef, forKey: .posterRef)
        try container.encodeIfPresent(posterMimeType, forKey: .posterMimeType)
        try container.encodeIfPresent(posterWidth, forKey: .posterWidth)
        try container.encodeIfPresent(posterHeight, forKey: .posterHeight)
    }
}

struct LiveRoom: Codable, Identifiable {
    let id: String
    let object: String?
    let community: String
    let anchorPost: String
    let hostUser: String
    let guestUser: String?
    let roomKind: String
    let status: String
    let accessMode: String
    let visibility: String
    let title: String
    let description: String?
    let coverRef: String?
    let eventStartAt: Int?
    let liveStartedAt: Int?
    let endedAt: Int?
    let canceledAt: Int?
    let broadcastRef: String?
    let replayStatus: String
    let performerAllocations: [LiveRoomPerformerAllocation]
    let setlist: LiveRoomSetlist
    let created: Int?

    enum CodingKeys: String, CodingKey {
        case id, object, community, status, visibility, title, description, created
        case anchorPost = "anchor_post"
        case hostUser = "host_user"
        case guestUser = "guest_user"
        case roomKind = "room_kind"
        case accessMode = "access_mode"
        case coverRef = "cover_ref"
        case eventStartAt = "event_start_at"
        case liveStartedAt = "live_started_at"
        case endedAt = "ended_at"
        case canceledAt = "canceled_at"
        case broadcastRef = "broadcast_ref"
        case replayStatus = "replay_status"
        case performerAllocations = "performer_allocations"
        case setlist
    }
}

struct LiveRoomPerformerAllocation: Codable, Identifiable {
    let id: String
    let object: String?
    let user: String
    let role: String
    let shareBps: Int

    enum CodingKeys: String, CodingKey {
        case id, object, user, role
        case shareBps = "share_bps"
    }
}

struct LiveRoomSetlist: Codable {
    let id: String
    let object: String?
    let status: String
    let items: [LiveRoomSetlistItem]
}

struct LiveRoomSetlistItem: Codable, Identifiable {
    let id: String
    let object: String?
    let position: Int
    let songArtifactBundle: String?
    let sourceAssetRef: String?
    let title: String
    let artist: String?
    let rightsBasis: String
    let licenseRef: String?
    let rightsStatus: String
    let blockingRightsFailure: Bool

    enum CodingKeys: String, CodingKey {
        case id, object, position, title, artist
        case songArtifactBundle = "song_artifact_bundle"
        case sourceAssetRef = "source_asset_ref"
        case rightsBasis = "rights_basis"
        case licenseRef = "license_ref"
        case rightsStatus = "rights_status"
        case blockingRightsFailure = "blocking_rights_failure"
    }
}

struct LiveRoomAccess: Codable {
    let allowed: Bool
    let decisionReason: String?
    let accessMode: String
    let visibility: String
    let listing: String?
    let purchaseEntitlement: String?
    let guestInviteStatus: String?

    enum CodingKeys: String, CodingKey {
        case allowed, visibility, listing
        case decisionReason = "decision_reason"
        case accessMode = "access_mode"
        case purchaseEntitlement = "purchase_entitlement"
        case guestInviteStatus = "guest_invite_status"
    }
}

struct LiveRoomAccessResponse: Codable {
    let room: LiveRoom
    let access: LiveRoomAccess
}

struct LiveRoomViewerAttachResponse: Codable {
    let room: LiveRoom
    let access: LiveRoomAccess
    let runtime: LiveRoomRuntime
    let agora: LiveRoomAgora
}

struct LiveRoomRuntime: Codable {
    let status: String
    let seat: String
    let roomRuntimeId: String

    enum CodingKeys: String, CodingKey {
        case status, seat
        case roomRuntimeId = "room_runtime_id"
    }
}

struct LiveRoomAgora: Codable {
    let appId: String?
    let channel: String
    let uid: UInt
    let token: String?
    let tokenExpiresAt: Int?
    let configured: Bool

    enum CodingKeys: String, CodingKey {
        case channel, uid, token, configured
        case appId = "app_id"
        case tokenExpiresAt = "token_expires_at"
    }
}

struct LiveRoomViewerRenewRequest: Codable {
    let uid: UInt
}

struct LocalizedPostResponse: Codable, Identifiable {
    let post: Post
    let threadSnapshot: [CommentListItem]?
    let commentCount: Int?
    let upvoteCount: Int?
    let downvoteCount: Int?
    let likeCount: Int?
    let viewerVote: Int?
    let locale: String?
    let flair: String?
    let translationState: String?
    let machineTranslated: Bool?
    let translatedTitle: String?
    let translatedBody: String?
    let translatedCaption: String?
    let sourceHash: String?

    enum CodingKeys: String, CodingKey {
        case post
        case threadSnapshot = "thread_snapshot"
        case commentCount = "comment_count"
        case upvoteCount = "upvote_count"
        case downvoteCount = "downvote_count"
        case likeCount = "like_count"
        case viewerVote = "viewer_vote"
        case locale, flair
        case resolvedLocale = "resolved_locale"
        case translationState = "translation_state"
        case machineTranslated = "machine_translated"
        case translatedTitle = "translated_title"
        case translatedBody = "translated_body"
        case translatedCaption = "translated_caption"
        case sourceHash = "source_hash"
    }

    var id: String { post.id }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.post = try container.decode(Post.self, forKey: .post)
        self.threadSnapshot = try? container.decodeIfPresent([CommentListItem].self, forKey: .threadSnapshot)
        self.commentCount = container.decodeLossyIntIfPresent(forKey: .commentCount)
        self.upvoteCount = container.decodeLossyIntIfPresent(forKey: .upvoteCount)
        self.downvoteCount = container.decodeLossyIntIfPresent(forKey: .downvoteCount)
        self.likeCount = container.decodeLossyIntIfPresent(forKey: .likeCount)
        self.viewerVote = container.decodeLossyIntIfPresent(forKey: .viewerVote)
        self.locale = container.decodeLossyStringIfPresent(forKey: .locale)
            ?? container.decodeLossyStringIfPresent(forKey: .resolvedLocale)
        self.flair = container.decodeLossyStringIfPresent(forKey: .flair)
        self.translationState = container.decodeLossyStringIfPresent(forKey: .translationState)
        self.machineTranslated = container.decodeLossyBoolIfPresent(forKey: .machineTranslated)
        self.translatedTitle = container.decodeLossyStringIfPresent(forKey: .translatedTitle)
        self.translatedBody = container.decodeLossyStringIfPresent(forKey: .translatedBody)
        self.translatedCaption = container.decodeLossyStringIfPresent(forKey: .translatedCaption)
        self.sourceHash = container.decodeLossyStringIfPresent(forKey: .sourceHash)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(post, forKey: .post)
        try container.encodeIfPresent(threadSnapshot, forKey: .threadSnapshot)
        try container.encodeIfPresent(commentCount, forKey: .commentCount)
        try container.encodeIfPresent(upvoteCount, forKey: .upvoteCount)
        try container.encodeIfPresent(downvoteCount, forKey: .downvoteCount)
        try container.encodeIfPresent(likeCount, forKey: .likeCount)
        try container.encodeIfPresent(viewerVote, forKey: .viewerVote)
        try container.encodeIfPresent(locale, forKey: .locale)
        try container.encodeIfPresent(flair, forKey: .flair)
        try container.encodeIfPresent(translationState, forKey: .translationState)
        try container.encodeIfPresent(machineTranslated, forKey: .machineTranslated)
        try container.encodeIfPresent(translatedTitle, forKey: .translatedTitle)
        try container.encodeIfPresent(translatedBody, forKey: .translatedBody)
        try container.encodeIfPresent(translatedCaption, forKey: .translatedCaption)
        try container.encodeIfPresent(sourceHash, forKey: .sourceHash)
    }
}

struct HomeFeedItem: Codable, Identifiable {
    let community: HomeFeedCommunitySummary
    let post: LocalizedPostResponse

    var id: String { post.id }
}

struct HomeFeedResponse: Codable {
    let items: [HomeFeedItem]
    let topCommunities: [HomeFeedCommunitySummary]?
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case topCommunities = "top_communities"
        case nextCursor = "next_cursor"
    }
}

enum ProfileActivityItem: Decodable, Identifiable {
    case post(ProfileActivityPostPage)
    case comment(ProfileActivityCommentPage)

    enum CodingKeys: String, CodingKey {
        case kind
    }

    var id: String {
        switch self {
        case .post(let item): return item.id
        case .comment(let item): return item.id
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = container.decodeLossyStringIfPresent(forKey: .kind)
        switch kind {
        case "post":
            self = .post(try ProfileActivityPostPage(from: decoder))
        case "comment":
            self = .comment(try ProfileActivityCommentPage(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown profile activity item kind"
            )
        }
    }

}

struct ProfileActivityPostPage: Decodable, Identifiable {
    let kind: String
    let post: LocalizedPostResponse
    let community: CommunityPreview
    let created: String?

    enum CodingKeys: String, CodingKey {
        case kind, post, community, created
        case createdAt = "created_at"
    }

    var id: String { "post:\(post.id)" }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = container.decodeLossyStringIfPresent(forKey: .kind) ?? "post"
        self.post = try container.decode(LocalizedPostResponse.self, forKey: .post)
        self.community = try container.decode(CommunityPreview.self, forKey: .community)
        self.created = container.decodeLossyStringIfPresent(forKey: .created)
            ?? container.decodeLossyStringIfPresent(forKey: .createdAt)
    }
}

struct ProfileActivityCommentPage: Decodable, Identifiable {
    let kind: String
    let comment: CommentListItem
    let threadRootPost: LocalizedPostResponse
    let community: CommunityPreview
    let created: String?

    enum CodingKeys: String, CodingKey {
        case kind, comment, community, created
        case threadRootPost = "thread_root_post"
        case createdAt = "created_at"
    }

    var id: String { "comment:\(comment.id)" }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.kind = container.decodeLossyStringIfPresent(forKey: .kind) ?? "comment"
        self.comment = try container.decode(CommentListItem.self, forKey: .comment)
        self.threadRootPost = try container.decode(LocalizedPostResponse.self, forKey: .threadRootPost)
        self.community = try container.decode(CommunityPreview.self, forKey: .community)
        self.created = container.decodeLossyStringIfPresent(forKey: .created)
            ?? container.decodeLossyStringIfPresent(forKey: .createdAt)
    }
}

struct ProfileActivityResponse: Decodable {
    let tab: String
    let posts: [ProfileActivityPostPage]
    let comments: [ProfileActivityCommentPage]
    let overviewItems: [ProfileActivityItem]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case tab, posts, comments
        case overviewItems = "overview_items"
        case nextCursor = "next_cursor"
    }
}

struct HomeFeedCommunitySummary: Codable, Identifiable {
    let communityId: String
    let displayName: String
    let routeSlug: String?
    let avatarRef: String?
    let memberCount: Int?
    let followerCount: Int?
    let viewerFollowing: Bool?

    enum CodingKeys: String, CodingKey {
        case communityId = "community_id"
        case id
        case community
        case displayName = "display_name"
        case routeSlug = "route_slug"
        case avatarRef = "avatar_ref"
        case memberCount = "member_count"
        case followerCount = "follower_count"
        case viewerFollowing = "viewer_following"
    }

    var id: String { communityId }

    var avatarURL: URL? {
        guard let ref = avatarRef else { return nil }
        return URL(string: ref)
    }

    init(
        communityId: String,
        displayName: String,
        routeSlug: String? = nil,
        avatarRef: String? = nil,
        memberCount: Int? = nil,
        followerCount: Int? = nil,
        viewerFollowing: Bool? = nil
    ) {
        self.communityId = communityId
        self.displayName = displayName
        self.routeSlug = routeSlug
        self.avatarRef = avatarRef
        self.memberCount = memberCount
        self.followerCount = followerCount
        self.viewerFollowing = viewerFollowing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.communityId = container.decodeLossyStringIfPresent(forKey: .communityId)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
            ?? container.decodeLossyStringIfPresent(forKey: .community)
            ?? ""
        self.displayName = container.decodeLossyStringIfPresent(forKey: .displayName) ?? "Community"
        self.routeSlug = container.decodeLossyStringIfPresent(forKey: .routeSlug)
        self.avatarRef = container.decodeLossyStringIfPresent(forKey: .avatarRef)
        self.memberCount = container.decodeLossyIntIfPresent(forKey: .memberCount)
        self.followerCount = container.decodeLossyIntIfPresent(forKey: .followerCount)
        self.viewerFollowing = container.decodeLossyBoolIfPresent(forKey: .viewerFollowing)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(communityId, forKey: .communityId)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(routeSlug, forKey: .routeSlug)
        try container.encodeIfPresent(avatarRef, forKey: .avatarRef)
        try container.encodeIfPresent(memberCount, forKey: .memberCount)
        try container.encodeIfPresent(followerCount, forKey: .followerCount)
        try container.encodeIfPresent(viewerFollowing, forKey: .viewerFollowing)
    }
}

struct Comment: Codable, Identifiable {
    let commentId: String
    let communityId: String?
    let threadRootPostId: String?
    let parentCommentId: String?
    let authorUserId: String?
    let authorDisplayName: String?
    let authorAvatarRef: String?
    let authorIdentityMode: String?
    let authorAnonymousScope: String?
    let authorAnonymousLabel: String?
    let body: String?
    let status: String?
    let depth: Int?
    let directReplyCount: Int?
    let descendantCount: Int?
    let upvoteCount: Int?
    let downvoteCount: Int?
    let score: Int?
    let lastReplyAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case commentId = "comment_id"
        case id
        case comment
        case communityId = "community_id"
        case community
        case threadRootPostId = "thread_root_post_id"
        case threadRootPost = "thread_root_post"
        case parentCommentId = "parent_comment_id"
        case parentComment = "parent_comment"
        case authorUserId = "author_user_id"
        case authorUser = "author_user"
        case authorDisplayName = "author_display_name"
        case authorAvatarRef = "author_avatar_ref"
        case authorIdentityMode = "author_identity_mode"
        case identityMode = "identity_mode"
        case authorAnonymousScope = "author_anonymous_scope"
        case anonymousScope = "anonymous_scope"
        case authorAnonymousLabel = "author_anonymous_label"
        case anonymousLabel = "anonymous_label"
        case body, status, depth
        case directReplyCount = "direct_reply_count"
        case descendantCount = "descendant_count"
        case upvoteCount = "upvote_count"
        case downvoteCount = "downvote_count"
        case score
        case lastReplyAt = "last_reply_at"
        case createdAt = "created_at"
        case created
        case updatedAt = "updated_at"
        case updated
    }

    var id: String { commentId }

    var authorAvatarURL: URL? {
        guard let ref = authorAvatarRef else { return nil }
        return URL(string: ref)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.commentId = container.decodeLossyStringIfPresent(forKey: .commentId)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
            ?? container.decodeLossyStringIfPresent(forKey: .comment)
            ?? ""
        self.communityId = container.decodeLossyStringIfPresent(forKey: .communityId)
            ?? container.decodeLossyStringIfPresent(forKey: .community)
        self.threadRootPostId = container.decodeLossyStringIfPresent(forKey: .threadRootPostId)
            ?? container.decodeLossyStringIfPresent(forKey: .threadRootPost)
        self.parentCommentId = container.decodeLossyStringIfPresent(forKey: .parentCommentId)
            ?? container.decodeLossyStringIfPresent(forKey: .parentComment)
        self.authorUserId = container.decodeLossyStringIfPresent(forKey: .authorUserId)
            ?? container.decodeLossyStringIfPresent(forKey: .authorUser)
        self.authorDisplayName = container.decodeLossyStringIfPresent(forKey: .authorDisplayName)
        self.authorAvatarRef = container.decodeLossyStringIfPresent(forKey: .authorAvatarRef)
        self.authorIdentityMode = container.decodeLossyStringIfPresent(forKey: .authorIdentityMode)
            ?? container.decodeLossyStringIfPresent(forKey: .identityMode)
        self.authorAnonymousScope = container.decodeLossyStringIfPresent(forKey: .authorAnonymousScope)
            ?? container.decodeLossyStringIfPresent(forKey: .anonymousScope)
        self.authorAnonymousLabel = container.decodeLossyStringIfPresent(forKey: .authorAnonymousLabel)
            ?? container.decodeLossyStringIfPresent(forKey: .anonymousLabel)
        self.body = container.decodeLossyStringIfPresent(forKey: .body)
        self.status = container.decodeLossyStringIfPresent(forKey: .status)
        self.depth = container.decodeLossyIntIfPresent(forKey: .depth)
        self.directReplyCount = container.decodeLossyIntIfPresent(forKey: .directReplyCount)
        self.descendantCount = container.decodeLossyIntIfPresent(forKey: .descendantCount)
        self.upvoteCount = container.decodeLossyIntIfPresent(forKey: .upvoteCount)
        self.downvoteCount = container.decodeLossyIntIfPresent(forKey: .downvoteCount)
        self.score = container.decodeLossyIntIfPresent(forKey: .score)
        self.lastReplyAt = container.decodeLossyStringIfPresent(forKey: .lastReplyAt)
        self.createdAt = container.decodeLossyStringIfPresent(forKey: .createdAt)
            ?? container.decodeLossyStringIfPresent(forKey: .created)
        self.updatedAt = container.decodeLossyStringIfPresent(forKey: .updatedAt)
            ?? container.decodeLossyStringIfPresent(forKey: .updated)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(commentId, forKey: .commentId)
        try container.encodeIfPresent(communityId, forKey: .communityId)
        try container.encodeIfPresent(threadRootPostId, forKey: .threadRootPostId)
        try container.encodeIfPresent(parentCommentId, forKey: .parentCommentId)
        try container.encodeIfPresent(authorUserId, forKey: .authorUserId)
        try container.encodeIfPresent(authorDisplayName, forKey: .authorDisplayName)
        try container.encodeIfPresent(authorAvatarRef, forKey: .authorAvatarRef)
        try container.encodeIfPresent(authorIdentityMode, forKey: .authorIdentityMode)
        try container.encodeIfPresent(authorAnonymousScope, forKey: .authorAnonymousScope)
        try container.encodeIfPresent(authorAnonymousLabel, forKey: .authorAnonymousLabel)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(depth, forKey: .depth)
        try container.encodeIfPresent(directReplyCount, forKey: .directReplyCount)
        try container.encodeIfPresent(descendantCount, forKey: .descendantCount)
        try container.encodeIfPresent(upvoteCount, forKey: .upvoteCount)
        try container.encodeIfPresent(downvoteCount, forKey: .downvoteCount)
        try container.encodeIfPresent(score, forKey: .score)
        try container.encodeIfPresent(lastReplyAt, forKey: .lastReplyAt)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct CommentListItem: Codable, Identifiable {
    let comment: Comment
    let viewerVote: Int?
    let resolvedLocale: String?
    let translationState: String?
    let machineTranslated: Bool?
    let translatedBody: String?
    let sourceHash: String?

    enum CodingKeys: String, CodingKey {
        case comment
        case viewerVote = "viewer_vote"
        case resolvedLocale = "resolved_locale"
        case translationState = "translation_state"
        case machineTranslated = "machine_translated"
        case translatedBody = "translated_body"
        case sourceHash = "source_hash"
    }

    var id: String { comment.id }
}

struct CommentListResponse: Codable {
    let items: [CommentListItem]
    let nextCursor: String?
    let threadSnapshot: [CommentListItem]?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
        case threadSnapshot = "thread_snapshot"
    }
}

struct PostVoteResponse: Codable {
    let id: String
    let value: Int
}

struct CommentVoteResponse: Codable {
    let id: String
    let value: Int
}

struct ErrorResponse: Codable {
    let code: String?
    let message: String?
    let retryable: Bool?

    enum CodingKeys: String, CodingKey {
        case code, message, retryable
    }

    var displayMessage: String {
        switch code {
        case "auth_error": return "Sign in to continue."
        case "internal_error": return "Something went wrong. Please try again."
        default: return message ?? "An unknown error occurred."
    }
    }
}

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

struct PublicProfileResolution: Codable {
    let profile: Profile
    let requestedHandleLabels: [String]?
    let resolvedHandleLabels: [String]?
    let isCanonical: Bool?
    let createdCommunities: [PublicProfileCommunitySummary]?

    enum CodingKeys: String, CodingKey {
        case profile
        case requestedHandleLabels = "requested_handle_labels"
        case requestedHandleLabel = "requested_handle_label"
        case resolvedHandleLabels = "resolved_handle_labels"
        case resolvedHandleLabel = "resolved_handle_label"
        case isCanonical = "is_canonical"
        case createdCommunities = "created_communities"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.profile = try container.decode(Profile.self, forKey: .profile)
        if let labels = try? container.decodeIfPresent([String].self, forKey: .requestedHandleLabels) {
            self.requestedHandleLabels = labels
        } else if let label = container.decodeLossyStringIfPresent(forKey: .requestedHandleLabel) {
            self.requestedHandleLabels = [label]
        } else {
            self.requestedHandleLabels = nil
        }
        if let labels = try? container.decodeIfPresent([String].self, forKey: .resolvedHandleLabels) {
            self.resolvedHandleLabels = labels
        } else if let label = container.decodeLossyStringIfPresent(forKey: .resolvedHandleLabel) {
            self.resolvedHandleLabels = [label]
        } else {
            self.resolvedHandleLabels = nil
        }
        self.isCanonical = container.decodeLossyBoolIfPresent(forKey: .isCanonical)
        self.createdCommunities = (try? container.decodeIfPresent([PublicProfileCommunitySummary].self, forKey: .createdCommunities)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profile, forKey: .profile)
        try container.encodeIfPresent(requestedHandleLabels, forKey: .requestedHandleLabels)
        try container.encodeIfPresent(resolvedHandleLabels, forKey: .resolvedHandleLabels)
        try container.encodeIfPresent(isCanonical, forKey: .isCanonical)
        try container.encodeIfPresent(createdCommunities, forKey: .createdCommunities)
    }
}

struct PublicProfileCommunitySummary: Codable, Identifiable {
    let communityId: String
    let displayName: String
    let routeSlug: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case communityId = "community_id"
        case id
        case community
        case displayName = "display_name"
        case routeSlug = "route_slug"
        case createdAt = "created_at"
        case created
    }

    var id: String { communityId }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.communityId = container.decodeLossyStringIfPresent(forKey: .communityId)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
            ?? container.decodeLossyStringIfPresent(forKey: .community)
            ?? ""
        self.displayName = container.decodeLossyStringIfPresent(forKey: .displayName) ?? "Community"
        self.routeSlug = container.decodeLossyStringIfPresent(forKey: .routeSlug)
        self.createdAt = container.decodeLossyStringIfPresent(forKey: .createdAt)
            ?? container.decodeLossyStringIfPresent(forKey: .created)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(communityId, forKey: .communityId)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(routeSlug, forKey: .routeSlug)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

struct SessionExchangeProof: Codable {
    let type: String
    let privyAccessToken: String
    let walletAddress: String?

    enum CodingKeys: String, CodingKey {
        case type
        case privyAccessToken = "privy_access_token"
        case walletAddress = "wallet_address"
    }
}

struct SessionExchangeRequest: Codable {
    let proof: SessionExchangeProof

    enum CodingKeys: String, CodingKey {
        case proof
    }
}

struct HandlePolicyInput: Codable {
    let policyTemplate: String

    init(policyTemplate: String = "standard") {
        self.policyTemplate = policyTemplate
    }

    enum CodingKeys: String, CodingKey {
        case policyTemplate = "policy_template"
    }
}

struct CreateCommunityRequest: Codable {
    let displayName: String
    let description: String?
    let databaseRegion: String?
    let membershipMode: String?
    let governanceMode: String?
    let defaultAgeGatePolicy: String?
    let allowAnonymousIdentity: Bool?
    let handlePolicy: HandlePolicyInput?

    init(
        displayName: String,
        description: String? = nil,
        databaseRegion: String? = "auto",
        membershipMode: String? = "open",
        governanceMode: String? = "centralized",
        defaultAgeGatePolicy: String? = "none",
        allowAnonymousIdentity: Bool? = false,
        handlePolicy: HandlePolicyInput? = HandlePolicyInput()
    ) {
        self.displayName = displayName
        self.description = description
        self.databaseRegion = databaseRegion
        self.membershipMode = membershipMode
        self.governanceMode = governanceMode
        self.defaultAgeGatePolicy = defaultAgeGatePolicy
        self.allowAnonymousIdentity = allowAnonymousIdentity
        self.handlePolicy = handlePolicy
    }

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case description
        case databaseRegion = "database_region"
        case membershipMode = "membership_mode"
        case governanceMode = "governance_mode"
        case defaultAgeGatePolicy = "default_age_gate_policy"
        case allowAnonymousIdentity = "allow_anonymous_identity"
        case handlePolicy = "handle_policy"
    }
}

struct CommunityCreateAcceptedResponse: Codable {
    let community: Community
    let job: Job?

    enum CodingKeys: String, CodingKey {
        case community, job
    }
}

struct Job: Codable {
    let jobId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
    }
}

struct CreatePostRequest: Codable {
    let idempotencyKey: String?
    let title: String?
    let body: String?
    let caption: String?
    let postType: String?
    let linkUrl: String?
    let ageGatePolicy: String?
    let flairId: String?
    let identityMode: String?
    let anonymousScope: String?
    let disclosedQualifierIds: [String]?
    let translationPolicy: String?
    let visibility: String?

    enum CodingKeys: String, CodingKey {
        case idempotencyKey = "idempotency_key"
        case title, body, caption
        case postType = "post_type"
        case linkUrl = "link_url"
        case ageGatePolicy = "age_gate_policy"
        case flairId = "flair_id"
        case identityMode = "identity_mode"
        case anonymousScope = "anonymous_scope"
        case disclosedQualifierIds = "disclosed_qualifier_ids"
        case translationPolicy = "translation_policy"
        case visibility
    }

    init(
        idempotencyKey: String? = nil,
        title: String? = nil,
        body: String? = nil,
        caption: String? = nil,
        postType: String? = nil,
        linkUrl: String? = nil,
        ageGatePolicy: String? = nil,
        flairId: String? = nil,
        identityMode: String? = nil,
        anonymousScope: String? = nil,
        disclosedQualifierIds: [String]? = nil,
        translationPolicy: String? = nil,
        visibility: String? = nil
    ) {
        self.idempotencyKey = idempotencyKey
        self.title = title
        self.body = body
        self.caption = caption
        self.postType = postType
        self.linkUrl = linkUrl
        self.ageGatePolicy = ageGatePolicy
        self.flairId = flairId
        self.identityMode = identityMode
        self.anonymousScope = anonymousScope
        self.disclosedQualifierIds = disclosedQualifierIds
        self.translationPolicy = translationPolicy
        self.visibility = visibility
    }
}

struct LinkPreviewResponse: Codable {
    let kind: String?
    let provider: String?
    let canonicalUrl: String?
    let originalUrl: String?
    let state: String?
    let title: String?
    let imageUrl: String?
    let preview: [String: JSONValue]?
    let oembedHtml: String?
    let oembedCacheAge: Int?

    enum CodingKeys: String, CodingKey {
        case kind, provider, state, title, preview
        case canonicalUrl = "canonical_url"
        case originalUrl = "original_url"
        case imageUrl = "image_url"
        case oembedHtml = "oembed_html"
        case oembedCacheAge = "oembed_cache_age"
    }
}

struct CreateCommentRequest: Codable {
    let body: String
    let identityMode: String?

    enum CodingKeys: String, CodingKey {
        case body
        case identityMode = "identity_mode"
    }
}

struct CommunityFollowResponse: Codable {
    let communityId: String
    let following: Bool?
    let followerCount: Int?

    enum CodingKeys: String, CodingKey {
        case communityId = "community_id"
        case following
        case followerCount = "follower_count"
    }
}

struct CommunityJoinResponse: Codable {
    let communityId: String
    let status: String?

    enum CodingKeys: String, CodingKey {
        case communityId = "community_id"
        case status
    }
}

struct VoteRequest: Codable {
    let value: Int
}

struct EmptyBody: Codable {}

struct PostListResponse: Codable {
    let items: [LocalizedPostResponse]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct VerificationSession: Codable, Identifiable {
    let id: String
    let status: String?
    let provider: String?
    let providerMode: String?
    let verificationIntent: String?
    let launch: JSONValue?
    let createdAt: String?
    let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case id, status, provider
        case providerMode = "provider_mode"
        case verificationIntent = "verification_intent"
        case launch
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

struct StartVerificationSessionRequest: Codable {
    let provider: String
    let providerMode: String?
    let requestedCapabilities: [String]?
    let walletAttachmentId: String?
    let verificationIntent: String?
    let policyId: String?

    init(
        provider: String,
        providerMode: String? = nil,
        requestedCapabilities: [String]? = nil,
        walletAttachmentId: String? = nil,
        verificationIntent: String? = nil,
        policyId: String? = nil
    ) {
        self.provider = provider
        self.providerMode = providerMode
        self.requestedCapabilities = requestedCapabilities
        self.walletAttachmentId = walletAttachmentId
        self.verificationIntent = verificationIntent
        self.policyId = policyId
    }

    enum CodingKeys: String, CodingKey {
        case provider
        case providerMode = "provider_mode"
        case requestedCapabilities = "requested_capabilities"
        case walletAttachmentId = "wallet_attachment_id"
        case verificationIntent = "verification_intent"
        case policyId = "policy_id"
    }
}

struct NamespaceVerificationSession: Codable, Identifiable {
    let sessionId: String
    let namespaceVerificationId: String?
    let family: String?
    let submittedRootLabel: String?
    let normalizedRootLabel: String?
    let status: String?
    let challengeKind: String?
    let challengeHost: String?
    let challengeTxtValue: String?
    let challengePayload: [String: JSONValue]?
    let challengeExpiresAt: String?
    let failureReason: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case namespaceVerificationSessionId = "namespace_verification_session_id"
        case namespaceVerificationId = "namespace_verification_id"
        case family, status
        case submittedRootLabel = "submitted_root_label"
        case normalizedRootLabel = "normalized_root_label"
        case challengeKind = "challenge_kind"
        case challengeHost = "challenge_host"
        case challengeTxtValue = "challenge_txt_value"
        case challengePayload = "challenge_payload"
        case challengeExpiresAt = "challenge_expires_at"
        case failureReason = "failure_reason"
        case createdAt = "created_at"
        case created
    }

    var id: String { sessionId }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.sessionId = container.decodeLossyStringIfPresent(forKey: .namespaceVerificationSessionId)
            ?? container.decodeLossyStringIfPresent(forKey: .sessionId)
            ?? ""
        self.namespaceVerificationId = container.decodeLossyStringIfPresent(forKey: .namespaceVerificationId)
        self.family = container.decodeLossyStringIfPresent(forKey: .family)
        self.submittedRootLabel = container.decodeLossyStringIfPresent(forKey: .submittedRootLabel)
        self.normalizedRootLabel = container.decodeLossyStringIfPresent(forKey: .normalizedRootLabel)
        self.status = container.decodeLossyStringIfPresent(forKey: .status)
        self.challengeKind = container.decodeLossyStringIfPresent(forKey: .challengeKind)
        self.challengeHost = container.decodeLossyStringIfPresent(forKey: .challengeHost)
        self.challengeTxtValue = container.decodeLossyStringIfPresent(forKey: .challengeTxtValue)
        self.challengePayload = try? container.decodeIfPresent([String: JSONValue].self, forKey: .challengePayload)
        self.challengeExpiresAt = container.decodeLossyStringIfPresent(forKey: .challengeExpiresAt)
        self.failureReason = container.decodeLossyStringIfPresent(forKey: .failureReason)
        self.createdAt = container.decodeLossyStringIfPresent(forKey: .createdAt)
            ?? container.decodeLossyStringIfPresent(forKey: .created)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionId, forKey: .namespaceVerificationSessionId)
        try container.encodeIfPresent(namespaceVerificationId, forKey: .namespaceVerificationId)
        try container.encodeIfPresent(family, forKey: .family)
        try container.encodeIfPresent(submittedRootLabel, forKey: .submittedRootLabel)
        try container.encodeIfPresent(normalizedRootLabel, forKey: .normalizedRootLabel)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(challengeKind, forKey: .challengeKind)
        try container.encodeIfPresent(challengeHost, forKey: .challengeHost)
        try container.encodeIfPresent(challengeTxtValue, forKey: .challengeTxtValue)
        try container.encodeIfPresent(challengePayload, forKey: .challengePayload)
        try container.encodeIfPresent(challengeExpiresAt, forKey: .challengeExpiresAt)
        try container.encodeIfPresent(failureReason, forKey: .failureReason)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

struct StartNamespaceVerificationSessionRequest: Codable {
    let family: String
    let rootLabel: String

    enum CodingKeys: String, CodingKey {
        case family
        case rootLabel = "root_label"
    }
}

struct CompleteNamespaceVerificationSessionRequest: Codable {
    let restartChallenge: Bool?

    enum CodingKeys: String, CodingKey {
        case restartChallenge = "restart_challenge"
    }
}

struct AttachNamespaceRequest: Codable {
    let namespaceVerificationId: String

    enum CodingKeys: String, CodingKey {
        case namespaceVerificationId = "namespace_verification_id"
    }
}

struct SetPendingNamespaceSessionRequest: Codable {
    let namespaceVerificationSessionId: String?

    enum CodingKeys: String, CodingKey {
        case namespaceVerificationSessionId = "namespace_verification_session_id"
    }
}
