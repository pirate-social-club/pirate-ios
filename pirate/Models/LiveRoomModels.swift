import Foundation

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

struct SongPresentation: Codable {
    let title: String?
    let coverArtRef: String?
    let durationMs: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case coverArtRef = "cover_art_ref"
        case durationMs = "duration_ms"
    }
}
