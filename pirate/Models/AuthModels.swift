import Foundation

struct AltchaChallenge: Codable {
    let rawValue: JSONValue

    init(from decoder: Decoder) throws {
        rawValue = try JSONValue(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try rawValue.encode(to: encoder)
    }

    func parameters() throws -> AltchaChallengeParameters {
        guard case .object(let root) = rawValue,
              case .object(let parameters)? = root["parameters"] else {
            throw AltchaSolverError.invalidChallenge("ALTCHA challenge is missing parameters.")
        }

        guard let algorithm = parameters["algorithm"]?.stringValue,
              let nonce = parameters["nonce"]?.stringValue,
              let salt = parameters["salt"]?.stringValue,
              let keyPrefix = parameters["keyPrefix"]?.stringValue,
              let cost = parameters["cost"]?.intValue,
              let keyLength = parameters["keyLength"]?.intValue else {
            throw AltchaSolverError.invalidChallenge("ALTCHA challenge has incomplete parameters.")
        }

        return AltchaChallengeParameters(
            algorithm: algorithm,
            cost: cost,
            keyLength: keyLength,
            keyPrefix: keyPrefix,
            maxNumber: parameters["maxNumber"]?.intValue ?? parameters["max_number"]?.intValue,
            nonce: nonce,
            salt: salt
        )
    }
}

struct AltchaChallengeParameters {
    let algorithm: String
    let cost: Int
    let keyLength: Int
    let keyPrefix: String
    let maxNumber: Int?
    let nonce: String
    let salt: String
}

struct AltchaSolution: Codable {
    let counter: Int
    let derivedKey: String
    let time: Int
}

struct AltchaPayloadEnvelope: Codable {
    let challenge: JSONValue
    let solution: AltchaSolution
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
