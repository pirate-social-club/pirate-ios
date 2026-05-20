import Foundation

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
        case namespaceVerification = "namespace_verification"
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
        self.namespaceVerificationId = container.decodeLossyStringIfPresent(forKey: .namespaceVerification)
            ?? container.decodeLossyStringIfPresent(forKey: .namespaceVerificationId)
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
        case namespaceVerification = "namespace_verification"
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
                namespaceVerificationId: container.decodeLossyStringIfPresent(forKey: .namespaceVerification)
                    ?? container.decodeLossyStringIfPresent(forKey: .namespaceVerificationId),
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
        case community
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.communityId = container.decodeLossyStringIfPresent(forKey: .community)
            ?? container.decodeLossyStringIfPresent(forKey: .communityId)
            ?? ""
        self.membershipMode = container.decodeLossyStringIfPresent(forKey: .membershipMode)
        self.humanVerificationLane = container.decodeLossyStringIfPresent(forKey: .humanVerificationLane)
        self.joinableNow = container.decodeLossyBoolIfPresent(forKey: .joinableNow)
        self.status = container.decodeLossyStringIfPresent(forKey: .status)
        self.membershipGateSummaries = (try? container.decodeIfPresent([MembershipGateSummary].self, forKey: .membershipGateSummaries)) ?? []
        self.missingCapabilities = (try? container.decodeIfPresent([String].self, forKey: .missingCapabilities)) ?? []
        self.suggestedVerificationProvider = container.decodeLossyStringIfPresent(forKey: .suggestedVerificationProvider)
        self.suggestedVerificationIntent = container.decodeLossyStringIfPresent(forKey: .suggestedVerificationIntent)
        self.failureReason = container.decodeLossyStringIfPresent(forKey: .failureReason)
        self.walletScoreStatus = try? container.decodeIfPresent(WalletScoreStatus.self, forKey: .walletScoreStatus)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(communityId, forKey: .community)
        try container.encodeIfPresent(membershipMode, forKey: .membershipMode)
        try container.encodeIfPresent(humanVerificationLane, forKey: .humanVerificationLane)
        try container.encodeIfPresent(joinableNow, forKey: .joinableNow)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(membershipGateSummaries, forKey: .membershipGateSummaries)
        try container.encodeIfPresent(missingCapabilities, forKey: .missingCapabilities)
        try container.encodeIfPresent(suggestedVerificationProvider, forKey: .suggestedVerificationProvider)
        try container.encodeIfPresent(suggestedVerificationIntent, forKey: .suggestedVerificationIntent)
        try container.encodeIfPresent(failureReason, forKey: .failureReason)
        try container.encodeIfPresent(walletScoreStatus, forKey: .walletScoreStatus)
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

struct CommunityListingListResponse: Codable {
    let items: [CommunityListing]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct CommunityListing: Codable, Identifiable {
    let id: String
    let object: String?
    let community: String
    let asset: String?
    let liveRoom: String?
    let listingMode: String?
    let status: String
    let priceCents: Int
    let regionalPricingEnabled: Bool?
    let donationPartner: String?
    let donationShareBps: Int?
    let createdByUser: String?
    let created: Int?

    enum CodingKeys: String, CodingKey {
        case id, object, community, asset, status, created
        case liveRoom = "live_room"
        case listingMode = "listing_mode"
        case priceCents = "price_cents"
        case regionalPricingEnabled = "regional_pricing_enabled"
        case donationPartner = "donation_partner"
        case donationShareBps = "donation_share_bps"
        case createdByUser = "created_by_user"
    }
}

struct CommunityPurchaseListResponse: Codable {
    let items: [CommunityPurchase]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct CommunityPurchase: Codable, Identifiable {
    let id: String
    let object: String?
    let community: String
    let listing: String
    let asset: String?
    let liveRoom: String?
    let buyerUser: String?
    let purchasePriceCents: Int
    let purchaseEntitlement: String?
    let entitlementKind: String?
    let entitlementTargetRef: String?
    let created: Int?

    enum CodingKeys: String, CodingKey {
        case id, object, community, listing, asset, created
        case liveRoom = "live_room"
        case buyerUser = "buyer_user"
        case purchasePriceCents = "purchase_price_cents"
        case purchaseEntitlement = "purchase_entitlement"
        case entitlementKind = "entitlement_kind"
        case entitlementTargetRef = "entitlement_target_ref"
    }
}

struct PostableCommunitySummary: Codable, Identifiable {
    let communityId: String
    let displayName: String
    let avatarRef: String?
    let routeSlug: String?
    let action: String

    enum CodingKeys: String, CodingKey {
        case communityId = "community_id"
        case displayName = "display_name"
        case avatarRef = "avatar_ref"
        case routeSlug = "route_slug"
        case action
    }

    var id: String { communityId }
}

struct PostableCommunitiesResponse: Codable {
    let communities: [PostableCommunitySummary]

    init(communities: [PostableCommunitySummary] = []) {
        self.communities = communities
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
    let avatarRef: String?
    let bannerRef: String?
    let databaseRegion: String?
    let membershipMode: String?
    let governanceMode: String?
    let defaultAgeGatePolicy: String?
    let allowAnonymousIdentity: Bool?
    let anonymousIdentityScope: String?
    let handlePolicy: HandlePolicyInput?
    let gatePolicy: JSONValue?
    let communityBootstrap: CreateCommunityBootstrapInput?

    init(
        displayName: String,
        description: String? = nil,
        avatarRef: String? = nil,
        bannerRef: String? = nil,
        databaseRegion: String? = "auto",
        membershipMode: String? = "gated",
        governanceMode: String? = "centralized",
        defaultAgeGatePolicy: String? = "none",
        allowAnonymousIdentity: Bool? = false,
        anonymousIdentityScope: String? = nil,
        handlePolicy: HandlePolicyInput? = HandlePolicyInput(),
        gatePolicy: JSONValue? = nil,
        communityBootstrap: CreateCommunityBootstrapInput? = nil
    ) {
        self.displayName = displayName
        self.description = description
        self.avatarRef = avatarRef
        self.bannerRef = bannerRef
        self.databaseRegion = databaseRegion
        self.membershipMode = membershipMode
        self.governanceMode = governanceMode
        self.defaultAgeGatePolicy = defaultAgeGatePolicy
        self.allowAnonymousIdentity = allowAnonymousIdentity
        self.anonymousIdentityScope = anonymousIdentityScope
        self.handlePolicy = handlePolicy
        self.gatePolicy = gatePolicy
        self.communityBootstrap = communityBootstrap
    }

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case description
        case avatarRef = "avatar_ref"
        case bannerRef = "banner_ref"
        case databaseRegion = "database_region"
        case membershipMode = "membership_mode"
        case governanceMode = "governance_mode"
        case defaultAgeGatePolicy = "default_age_gate_policy"
        case allowAnonymousIdentity = "allow_anonymous_identity"
        case anonymousIdentityScope = "anonymous_identity_scope"
        case handlePolicy = "handle_policy"
        case gatePolicy = "gate_policy"
        case communityBootstrap = "community_bootstrap"
    }
}

struct CreateCommunityBootstrapInput: Codable {
    let rules: [CreateCommunityRuleInput]
}

struct CreateCommunityRuleInput: Codable {
    let title: String
    let body: String
    let reportReason: String
    let position: Int

    enum CodingKeys: String, CodingKey {
        case title, body, position
        case reportReason = "report_reason"
    }
}

struct CommunityCreateAcceptedResponse: Codable {
    let community: Community
    let job: Job?

    enum CodingKeys: String, CodingKey {
        case community, job
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
        case community
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.communityId = container.decodeLossyStringIfPresent(forKey: .community)
            ?? container.decodeLossyStringIfPresent(forKey: .communityId)
            ?? ""
        self.status = container.decodeLossyStringIfPresent(forKey: .status)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(communityId, forKey: .community)
        try container.encodeIfPresent(status, forKey: .status)
    }
}

struct RefreshPassportWalletScoreRequest: Codable {
    let communityId: String?

    enum CodingKeys: String, CodingKey {
        case communityId = "community"
    }
}

struct RefreshPassportWalletScoreResponse: Codable {
    let walletScore: Double?
    let walletScoreStatus: WalletScoreStatus?
    let joinEligibility: JoinEligibility?

    enum CodingKeys: String, CodingKey {
        case walletScore = "wallet_score"
        case walletScoreStatus = "wallet_score_status"
        case joinEligibility = "join_eligibility"
    }
}
