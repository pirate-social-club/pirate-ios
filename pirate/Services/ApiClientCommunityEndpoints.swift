import Foundation

// MARK: - Communities
extension ApiClient {
    func community(id: String) async throws -> CommunityPreview {
        return try await request(path: "/communities/\(pathSegment(id))/preview")
    }

    func publicCommunity(id: String, locale: String? = nil) async throws -> CommunityPreview {
        return try await request(path: "/public-communities/\(pathSegment(id))", queryItems: Self.makeQueryItems((name: "locale", value: locale)), requireAuth: false)
    }

    func communityPosts(communityId: String, cursor: String? = nil, sort: String? = nil, limit: Int? = nil, locale: String? = nil) async throws -> PostListResponse {
        return try await request(path: "/communities/\(pathSegment(communityId))/posts", queryItems: listQueryItems(cursor: cursor, sort: sort, limit: limit, locale: locale))
    }

    func publicCommunityPosts(communityId: String, cursor: String? = nil, sort: String? = nil, limit: Int? = nil, locale: String? = nil) async throws -> PostListResponse {
        return try await request(path: "/public-communities/\(pathSegment(communityId))/posts", queryItems: listQueryItems(cursor: cursor, sort: sort, limit: limit, locale: locale), requireAuth: false)
    }

    func listQueryItems(cursor: String?, sort: String?, limit: Int?, locale: String? = nil) -> [URLQueryItem]? {
        Self.makeQueryItems(
            (name: "cursor", value: cursor),
            (name: "sort", value: sort),
            (name: "limit", value: limit.map(String.init)),
            (name: "locale", value: locale)
        )
    }

    func joinCommunity(communityId: String, altchaPayload: String? = nil) async throws -> CommunityJoinResponse {
        return try await request(
            path: "/communities/\(pathSegment(communityId))/join",
            method: .POST,
            body: encode(EmptyBody()),
            headers: altchaHeaders(altchaPayload)
        )
    }

    func followCommunity(communityId: String) async throws -> CommunityFollowResponse {
        return try await request(path: "/communities/\(pathSegment(communityId))/follow", method: .POST)
    }

    func unfollowCommunity(communityId: String) async throws -> CommunityFollowResponse {
        return try await request(path: "/communities/\(pathSegment(communityId))/follow", method: .DELETE)
    }

    func joinEligibility(communityId: String) async throws -> JoinEligibility {
        return try await request(path: "/communities/\(pathSegment(communityId))/join-eligibility")
    }

    func createCommunity(_ community: CreateCommunityRequest) async throws -> CommunityCreateAcceptedResponse {
        return try await request(path: "/communities", method: .POST, body: encode(community))
    }

    func attachNamespace(communityId: String, namespaceVerificationId: String) async throws -> Community {
        let body = AttachNamespaceRequest(namespaceVerificationId: namespaceVerificationId)
        return try await request(path: "/communities/\(pathSegment(communityId))/namespace", method: .POST, body: encode(body))
    }

    func setPendingNamespaceSession(communityId: String, sessionId: String?) async throws -> Community {
        let body = SetPendingNamespaceSessionRequest(namespaceVerificationSessionId: sessionId)
        return try await request(path: "/communities/\(pathSegment(communityId))/pending-namespace-session", method: .PUT, body: encode(body))
    }

    func getLiveRoomAccess(communityId: String, liveRoomId: String) async throws -> LiveRoomAccessResponse {
        return try await request(
            path: "/communities/\(pathSegment(communityId))/live-rooms/\(pathSegment(liveRoomId))/access"
        )
    }

    func viewerAttachLiveRoom(communityId: String, liveRoomId: String) async throws -> LiveRoomViewerAttachResponse {
        return try await request(
            path: "/communities/\(pathSegment(communityId))/live-rooms/\(pathSegment(liveRoomId))/viewer_attach",
            method: .POST
        )
    }

    func viewerRenewLiveRoom(communityId: String, liveRoomId: String, uid: UInt) async throws -> LiveRoomViewerAttachResponse {
        return try await request(
            path: "/communities/\(pathSegment(communityId))/live-rooms/\(pathSegment(liveRoomId))/viewer_renew",
            method: .POST,
            body: encode(LiveRoomViewerRenewRequest(uid: uid))
        )
    }

    func publicLiveRoomAccess(communityId: String, liveRoomId: String) async throws -> LiveRoomAccessResponse {
        return try await request(
            path: "/public-communities/\(pathSegment(communityId))/live-rooms/\(pathSegment(liveRoomId))/access",
            requireAuth: false
        )
    }

    func publicViewerAttachLiveRoom(communityId: String, liveRoomId: String) async throws -> LiveRoomViewerAttachResponse {
        return try await request(
            path: "/public-communities/\(pathSegment(communityId))/live-rooms/\(pathSegment(liveRoomId))/viewer_attach",
            method: .POST,
            requireAuth: false
        )
    }

    func publicViewerRenewLiveRoom(communityId: String, liveRoomId: String, uid: UInt) async throws -> LiveRoomViewerAttachResponse {
        return try await request(
            path: "/public-communities/\(pathSegment(communityId))/live-rooms/\(pathSegment(liveRoomId))/viewer_renew",
            method: .POST,
            body: encode(LiveRoomViewerRenewRequest(uid: uid)),
            requireAuth: false
        )
    }

    func communityListings(communityId: String) async throws -> CommunityListingListResponse {
        return try await request(path: "/communities/\(pathSegment(communityId))/listings")
    }

    func communityPurchases(communityId: String) async throws -> CommunityPurchaseListResponse {
        return try await request(path: "/communities/\(pathSegment(communityId))/purchases")
    }

    func communityAssetContentURL(communityId: String, assetId: String) -> URL {
        makeURL(path: "/communities/\(pathSegment(communityId))/assets/\(pathSegment(assetId))/content")
    }
}
