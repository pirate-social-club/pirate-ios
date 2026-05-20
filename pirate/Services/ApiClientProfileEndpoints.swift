import Foundation

// MARK: - Profiles
extension ApiClient {
    func myProfile() async throws -> Profile {
        return try await request(path: "/profiles/me")
    }

    func postableCommunities() async throws -> PostableCommunitiesResponse {
        return try await request(path: "/profiles/me/postable-communities")
    }

    func profile(userId: String) async throws -> Profile {
        return try await request(path: "/profiles/\(pathSegment(userId))", requireAuth: false)
    }

    func publicProfile(handle: String) async throws -> PublicProfileResolution {
        return try await request(path: "/public-profiles/\(pathSegment(handle))", requireAuth: false)
    }

    func publicProfileByWallet(address: String) async throws -> PublicProfileResolution {
        return try await request(path: "/public-profiles/by-wallet/\(pathSegment(address))", requireAuth: false)
    }

    func updateProfile(_ updates: [String: String]) async throws -> Profile {
        return try await request(path: "/profiles/me", method: .POST, body: encode(updates))
    }

    func updateProfile(_ updates: ProfileUpdateInput) async throws -> Profile {
        return try await request(path: "/profiles/me", method: .POST, body: encode(updates))
    }

    func uploadProfileMedia(kind: String, data: Data, filename: String, mimeType: String) async throws -> ProfileMediaUploadResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        let body = multipartProfileMediaBody(
            boundary: boundary,
            kind: kind,
            data: data,
            filename: filename,
            mimeType: mimeType
        )
        return try await requestMultipart(path: "/profile-media", body: body, boundary: boundary)
    }

    func uploadCommunityMedia(kind: String, data: Data, filename: String, mimeType: String) async throws -> ProfileMediaUploadResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        let body = multipartProfileMediaBody(
            boundary: boundary,
            kind: kind,
            data: data,
            filename: filename,
            mimeType: mimeType
        )
        return try await requestMultipart(path: "/community-media", body: body, boundary: boundary)
    }

    private func multipartProfileMediaBody(
        boundary: String,
        kind: String,
        data: Data,
        filename: String,
        mimeType: String
    ) -> Data {
        var body = Data()
        body.appendMultipartString("--\(boundary)\r\n")
        body.appendMultipartString("Content-Disposition: form-data; name=\"kind\"\r\n\r\n")
        body.appendMultipartString("\(kind)\r\n")
        body.appendMultipartString("--\(boundary)\r\n")
        body.appendMultipartString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.appendMultipartString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.appendMultipartString("\r\n--\(boundary)--\r\n")
        return body
    }

    func renameGlobalHandle(desiredLabel: String) async throws -> RenameHandleResponse {
        let body = encode(RenameHandleRequest(desiredLabel: desiredLabel))
        do {
            return try await request(path: "/profiles/me/rename-global-handle", method: .POST, body: body)
        } catch let error as ApiError where error.isNotFound {
            return try await request(path: "/profiles/me/global-handle/rename", method: .POST, body: body)
        }
    }

    func myProfileActivity(tab: String, cursor: String? = nil, limit: Int? = nil, locale: String? = nil) async throws -> ProfileActivityResponse {
        return try await profileActivity(path: "/profiles/me/activity", tab: tab, cursor: cursor, limit: limit, locale: locale)
    }

    func profileActivity(userId: String, tab: String, cursor: String? = nil, limit: Int? = nil, locale: String? = nil) async throws -> ProfileActivityResponse {
        return try await profileActivity(path: "/profiles/\(pathSegment(userId))/activity", tab: tab, cursor: cursor, limit: limit, locale: locale)
    }

    func publicProfileActivity(handle: String, tab: String, cursor: String? = nil, limit: Int? = nil, locale: String? = nil) async throws -> ProfileActivityResponse {
        return try await profileActivity(
            path: "/public-profiles/\(pathSegment(handle))/activity",
            tab: tab,
            cursor: cursor,
            limit: limit,
            locale: locale,
            requireAuth: false
        )
    }

    func publishXmtpInbox(_ inboxId: String) async throws -> Profile {
        let body = XmtpInboxUpdateInput(xmtpInbox: inboxId)
        return try await request(path: "/profiles/me/xmtp-inbox", method: .POST, body: encode(body))
    }

    private func profileActivity(
        path: String,
        tab: String,
        cursor: String? = nil,
        limit: Int? = nil,
        locale: String? = nil,
        requireAuth: Bool = true
    ) async throws -> ProfileActivityResponse {
        return try await request(
            path: path,
            queryItems: Self.makeQueryItems(
                (name: "tab", value: tab),
                (name: "cursor", value: cursor),
                (name: "limit", value: limit.map(String.init)),
                (name: "locale", value: locale)
            ),
            requireAuth: requireAuth
        )
    }
}

private extension Data {
    mutating func appendMultipartString(_ value: String) {
        if let data = value.data(using: .utf8) {
            append(data)
        }
    }
}
