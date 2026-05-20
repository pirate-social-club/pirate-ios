import Foundation

struct UserVerificationCapability: Codable, Equatable {
    let state: String?
    let provider: String?
    let proofType: String?
    let mechanism: String?
    let verifiedAt: String?
    let value: JSONValue?

    enum CodingKeys: String, CodingKey {
        case state, provider, mechanism, value
        case proofType = "proof_type"
        case verifiedAt = "verified_at"
    }

    init(
        state: String? = nil,
        provider: String? = nil,
        proofType: String? = nil,
        mechanism: String? = nil,
        verifiedAt: String? = nil,
        value: JSONValue? = nil
    ) {
        self.state = state
        self.provider = provider
        self.proofType = proofType
        self.mechanism = mechanism
        self.verifiedAt = verifiedAt
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.state = container.decodeLossyStringIfPresent(forKey: .state)
        self.provider = container.decodeLossyStringIfPresent(forKey: .provider)
        self.proofType = container.decodeLossyStringIfPresent(forKey: .proofType)
        self.mechanism = container.decodeLossyStringIfPresent(forKey: .mechanism)
        self.verifiedAt = container.decodeLossyStringIfPresent(forKey: .verifiedAt)
        self.value = try container.decodeIfPresent(JSONValue.self, forKey: .value)
    }
}

struct UserVerificationCapabilities: Codable, Equatable {
    let uniqueHuman: UserVerificationCapability?
    let ageOver18: UserVerificationCapability?
    let minimumAge: UserVerificationCapability?
    let nationality: UserVerificationCapability?
    let gender: UserVerificationCapability?
    let walletScore: UserVerificationCapability?

    enum CodingKeys: String, CodingKey {
        case uniqueHuman = "unique_human"
        case ageOver18 = "age_over_18"
        case minimumAge = "minimum_age"
        case nationality
        case gender
        case walletScore = "wallet_score"
    }

    init(
        uniqueHuman: UserVerificationCapability? = nil,
        ageOver18: UserVerificationCapability? = nil,
        minimumAge: UserVerificationCapability? = nil,
        nationality: UserVerificationCapability? = nil,
        gender: UserVerificationCapability? = nil,
        walletScore: UserVerificationCapability? = nil
    ) {
        self.uniqueHuman = uniqueHuman
        self.ageOver18 = ageOver18
        self.minimumAge = minimumAge
        self.nationality = nationality
        self.gender = gender
        self.walletScore = walletScore
    }
}

struct User: Codable, Identifiable {
    let userId: String
    let createdAt: String?
    let verificationState: String?
    let capabilityProvider: String?
    let verificationCapabilities: UserVerificationCapabilities?
    let verifiedAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case id
        case createdAt = "created_at"
        case created
        case verificationState = "verification_state"
        case capabilityProvider = "capability_provider"
        case verificationCapabilities = "verification_capabilities"
        case verifiedAt = "verified_at"
    }

    var id: String { userId }

    init(
        userId: String,
        createdAt: String? = nil,
        verificationState: String? = nil,
        capabilityProvider: String? = nil,
        verificationCapabilities: UserVerificationCapabilities? = nil,
        verifiedAt: String? = nil
    ) {
        self.userId = userId
        self.createdAt = createdAt
        self.verificationState = verificationState
        self.capabilityProvider = capabilityProvider
        self.verificationCapabilities = verificationCapabilities
        self.verifiedAt = verifiedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = container.decodeLossyStringIfPresent(forKey: .userId)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
            ?? ""
        self.createdAt = container.decodeLossyStringIfPresent(forKey: .createdAt)
            ?? container.decodeLossyStringIfPresent(forKey: .created)
        self.verificationState = container.decodeLossyStringIfPresent(forKey: .verificationState)
        self.capabilityProvider = container.decodeLossyStringIfPresent(forKey: .capabilityProvider)
        self.verificationCapabilities = try container.decodeIfPresent(UserVerificationCapabilities.self, forKey: .verificationCapabilities)
        self.verifiedAt = container.decodeLossyStringIfPresent(forKey: .verifiedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(verificationState, forKey: .verificationState)
        try container.encodeIfPresent(capabilityProvider, forKey: .capabilityProvider)
        try container.encodeIfPresent(verificationCapabilities, forKey: .verificationCapabilities)
        try container.encodeIfPresent(verifiedAt, forKey: .verifiedAt)
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
