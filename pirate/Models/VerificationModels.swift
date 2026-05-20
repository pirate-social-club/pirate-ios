import Foundation

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = container.decodeLossyStringIfPresent(forKey: .id) ?? ""
        self.status = container.decodeLossyStringIfPresent(forKey: .status)
        self.provider = container.decodeLossyStringIfPresent(forKey: .provider)
        self.providerMode = container.decodeLossyStringIfPresent(forKey: .providerMode)
        self.verificationIntent = container.decodeLossyStringIfPresent(forKey: .verificationIntent)
        self.launch = try container.decodeIfPresent(JSONValue.self, forKey: .launch)
        self.createdAt = container.decodeLossyStringIfPresent(forKey: .createdAt)
        self.expiresAt = container.decodeLossyStringIfPresent(forKey: .expiresAt)
    }
}

struct StartVerificationSessionRequest: Codable {
    let provider: String
    let providerMode: String?
    let requestedCapabilities: [String]?
    let verificationRequirements: [VerificationRequirement]?
    let walletAttachmentId: String?
    let verificationIntent: String?
    let policyId: String?

    init(
        provider: String,
        providerMode: String? = nil,
        requestedCapabilities: [String]? = nil,
        verificationRequirements: [VerificationRequirement]? = nil,
        walletAttachmentId: String? = nil,
        verificationIntent: String? = nil,
        policyId: String? = nil
    ) {
        self.provider = provider
        self.providerMode = providerMode
        self.requestedCapabilities = requestedCapabilities
        self.verificationRequirements = verificationRequirements
        self.walletAttachmentId = walletAttachmentId
        self.verificationIntent = verificationIntent
        self.policyId = policyId
    }

    enum CodingKeys: String, CodingKey {
        case provider
        case providerMode = "provider_mode"
        case requestedCapabilities = "requested_capabilities"
        case verificationRequirements = "verification_requirements"
        case walletAttachmentId = "wallet_attachment_id"
        case verificationIntent = "verification_intent"
        case policyId = "policy_id"
    }
}

struct VerificationRequirement: Codable, Equatable {
    let proofType: String
    let minimumAge: Int?
    let requiredValues: [String]?

    init(proofType: String, minimumAge: Int? = nil, requiredValues: [String]? = nil) {
        self.proofType = proofType
        self.minimumAge = minimumAge
        self.requiredValues = requiredValues
    }

    enum CodingKeys: String, CodingKey {
        case proofType = "proof_type"
        case minimumAge = "minimum_age"
        case requiredValues = "required_values"
    }
}

struct CompleteVerificationSessionRequest: Codable {
    let attestationId: String?
    let proof: String?
    let proofHash: String?
    let providerPayloadRef: JSONValue?

    init(
        attestationId: String? = nil,
        proof: String? = nil,
        proofHash: String? = nil,
        providerPayloadRef: JSONValue? = nil
    ) {
        self.attestationId = attestationId
        self.proof = proof
        self.proofHash = proofHash
        self.providerPayloadRef = providerPayloadRef
    }

    enum CodingKeys: String, CodingKey {
        case attestationId = "attestation_id"
        case proof
        case proofHash = "proof_hash"
        case providerPayloadRef = "provider_payload_ref"
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
