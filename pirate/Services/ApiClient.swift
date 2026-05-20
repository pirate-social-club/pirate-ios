import Foundation

enum ApiError: Error {
    case networkError(NetworkError)
    case serverError(statusCode: Int, message: String, code: String?, retryable: Bool, details: JSONValue? = nil)
    case decodingError(String)
    case unauthorized(String)
    case unknown(String)

    var displayMessage: String {
        switch self {
        case .networkError:
            return "Unable to connect. Please check your internet connection."
        case .serverError(_, let message, let code, _, _):
            if code == "auth_error" { return "Sign in to continue." }
            if code == "internal_error" { return "Something went wrong. Please try again." }
            return message
        case .decodingError:
            return "Something went wrong. Please try again."
        case .unauthorized:
            return "Sign in to continue."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }

    var diagnosticMessage: String {
        switch self {
        case .serverError(let statusCode, let message, let code, _, _):
            let codeLabel = code ?? "unknown"
            if message == displayMessage {
                return "\(message) (HTTP \(statusCode), \(codeLabel))"
            }
            return "\(displayMessage) (HTTP \(statusCode), \(codeLabel): \(message))"
        case .decodingError(let message):
            return "\(displayMessage) (\(message))"
        case .unauthorized(let message):
            return "\(displayMessage) (\(message))"
        case .unknown(let message):
            return "\(displayMessage) (\(message))"
        case .networkError:
            return displayMessage
        }
    }

    var isAuthError: Bool {
        if case .serverError(_, _, let code, _, _) = self, code == "auth_error" { return true }
        if case .unauthorized = self { return true }
        return false
    }

    var isNotFound: Bool {
        if case .serverError(let statusCode, _, _, _, _) = self, statusCode == 404 { return true }
        return false
    }

    var isForbidden: Bool {
        if case .serverError(let statusCode, _, _, _, _) = self, statusCode == 403 { return true }
        return false
    }

    var isRetryable: Bool {
        if case .serverError(_, _, _, let retryable, _) = self { return retryable }
        return false
    }

    var code: String? {
        if case .serverError(_, _, let code, _, _) = self { return code }
        if case .unauthorized = self { return "auth_error" }
        return nil
    }

    var details: JSONValue? {
        if case .serverError(_, _, _, _, let details) = self { return details }
        return nil
    }
}

enum NetworkError: Error {
    case noConnection
    case timeout
    case other(String)
}

enum HTTPMethod: String {
    case GET, POST, PUT, DELETE, PATCH
}

private let altchaHeaderName = "x-pirate-altcha"

final class ApiClient {
    static let shared = ApiClient()

    private var baseURL: URL = URL(string: "https://api.pirate.sc")!
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    private var accessToken: String?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = JSONEncoder()
    }

    func setBaseURL(_ url: URL) {
        self.baseURL = url
    }

    func publicMediaURL(from value: String?) -> URL? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        let normalized = trimmed.lowercased()
        if normalized.hasPrefix("http://") || normalized.hasPrefix("https://") || normalized.hasPrefix("data:") {
            return URL(string: trimmed)
        }

        if trimmed.range(of: "^[A-Za-z][A-Za-z0-9+.-]*:", options: .regularExpression) != nil {
            return nil
        }

        let path = trimmed.hasPrefix("/") ? trimmed : "/\(trimmed)"
        return URL(string: path, relativeTo: baseURL)?.absoluteURL
    }

    func setAccessToken(_ token: String?) {
        self.accessToken = token
    }

    func authorizationHeaders() -> [String: String]? {
        guard let accessToken else { return nil }
        return ["Authorization": "Bearer \(accessToken)"]
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]? = nil) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems?.isEmpty == true ? nil : queryItems
        return components.url!
    }

    private func pathSegment(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func makeRequest(
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        queryItems: [URLQueryItem]? = nil,
        requireAuth: Bool = true,
        contentType: String? = "application/json",
        headers: [String: String]? = nil
    ) -> URLRequest {
        let url = makeURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if requireAuth, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = body
        }

        return request
    }

    func request<T: Decodable>(path: String, method: HTTPMethod = .GET, body: Data? = nil, queryItems: [URLQueryItem]? = nil, requireAuth: Bool = true, headers: [String: String]? = nil) async throws -> T {
        let request = makeRequest(path: path, method: method, body: body, queryItems: queryItems, requireAuth: requireAuth, headers: headers)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ApiError.networkError(.noConnection)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.serverError(statusCode: 0, message: "Invalid response", code: nil, retryable: false)
        }

        if httpResponse.statusCode == 401 {
            if let errorResponse = try? jsonDecoder.decode(ErrorResponse.self, from: data) {
                throw ApiError.unauthorized(errorResponse.displayMessage)
            }
            throw ApiError.unauthorized("Session expired")
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? jsonDecoder.decode(ErrorResponse.self, from: data) {
                #if DEBUG
                print("[ApiClient] \(method.rawValue) \(path) failed HTTP \(httpResponse.statusCode) code=\(errorResponse.code ?? "nil") message=\(errorResponse.message ?? "nil")")
                #endif
                throw ApiError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse.message ?? errorResponse.displayMessage,
                    code: errorResponse.code,
                    retryable: errorResponse.retryable ?? false,
                    details: errorResponse.details
                )
            }
            throw ApiError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Request failed with status \(httpResponse.statusCode)",
                code: nil,
                retryable: httpResponse.statusCode >= 500
            )
        }

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            let diagnostic = Self.describeDecodingError(error)
            #if DEBUG
            print("[ApiClient] \(method.rawValue) \(path) decode failed for \(T.self): \(diagnostic)")
            print("[ApiClient] response preview: \(Self.redactedResponsePreview(from: data))")
            #endif
            throw ApiError.decodingError(diagnostic)
        }
    }

    func requestOptionalAuth<T: Decodable>(path: String, method: HTTPMethod = .GET, body: Data? = nil, queryItems: [URLQueryItem]? = nil, headers: [String: String]? = nil) async throws -> T {
        do {
            return try await request(path: path, method: method, body: body, queryItems: queryItems, requireAuth: true, headers: headers)
        } catch let error as ApiError {
            if error.isAuthError {
                return try await request(path: path, method: method, body: body, queryItems: queryItems, requireAuth: false, headers: headers)
            }
            throw error
        }
    }

    func requestVoid(path: String, method: HTTPMethod = .POST, body: Data? = nil, queryItems: [URLQueryItem]? = nil, requireAuth: Bool = true, headers: [String: String]? = nil) async throws {
        let request = makeRequest(path: path, method: method, body: body, queryItems: queryItems, requireAuth: requireAuth, headers: headers)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ApiError.networkError(.noConnection)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.serverError(statusCode: 0, message: "Invalid response", code: nil, retryable: false)
        }

        if httpResponse.statusCode == 401 {
            throw ApiError.unauthorized("Session expired")
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? jsonDecoder.decode(ErrorResponse.self, from: data) {
                #if DEBUG
                print("[ApiClient] \(method.rawValue) \(path) failed HTTP \(httpResponse.statusCode) code=\(errorResponse.code ?? "nil") message=\(errorResponse.message ?? "nil")")
                #endif
                throw ApiError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse.message ?? errorResponse.displayMessage,
                    code: errorResponse.code,
                    retryable: errorResponse.retryable ?? false,
                    details: errorResponse.details
                )
            }
            throw ApiError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Request failed with status \(httpResponse.statusCode)",
                code: nil,
                retryable: httpResponse.statusCode >= 500
            )
        }
    }

    private func encode<T: Encodable>(_ value: T) -> Data? {
        try? jsonEncoder.encode(value)
    }

    private func altchaHeaders(_ payload: String?) -> [String: String]? {
        guard let payload = payload?.trimmingCharacters(in: .whitespacesAndNewlines), !payload.isEmpty else {
            return nil
        }
        return [altchaHeaderName: payload]
    }

    private static func describeDecodingError(_ error: Error) -> String {
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .typeMismatch(let type, let context):
                return "Type mismatch for \(type) at \(formatCodingPath(context.codingPath)): \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                return "Missing value for \(type) at \(formatCodingPath(context.codingPath)): \(context.debugDescription)"
            case .keyNotFound(let key, let context):
                let path = formatCodingPath(context.codingPath + [key])
                return "Missing key at \(path): \(context.debugDescription)"
            case .dataCorrupted(let context):
                return "Data corrupted at \(formatCodingPath(context.codingPath)): \(context.debugDescription)"
            @unknown default:
                return error.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private static func formatCodingPath(_ codingPath: [CodingKey]) -> String {
        guard !codingPath.isEmpty else { return "<root>" }
        return codingPath.map(\.stringValue).joined(separator: ".")
    }

    private static func redactedResponsePreview(from data: Data) -> String {
        let maxLength = 1_500
        guard !data.isEmpty else { return "<empty>" }

        if var object = try? JSONSerialization.jsonObject(with: data) {
            redactSensitiveFields(in: &object)
            if let redactedData = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
               let redactedString = String(data: redactedData, encoding: .utf8) {
                return String(redactedString.prefix(maxLength))
            }
        }

        let fallback = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
        return String(fallback.prefix(maxLength))
    }

    private static func redactSensitiveFields(in value: inout Any) {
        let sensitiveKeys = Set(["access_token", "token", "jwt", "privy_access_token"])

        if var dictionary = value as? [String: Any] {
            for key in dictionary.keys {
                if sensitiveKeys.contains(key) {
                    dictionary[key] = "<redacted>"
                } else if var nested = dictionary[key] {
                    redactSensitiveFields(in: &nested)
                    dictionary[key] = nested
                }
            }
            value = dictionary
        } else if var array = value as? [Any] {
            for index in array.indices {
                var nested = array[index]
                redactSensitiveFields(in: &nested)
                array[index] = nested
            }
            value = array
        }
    }
}

private extension Data {
    mutating func appendMultipartString(_ value: String) {
        if let data = value.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - Auth
extension ApiClient {
    func communityDetails(id: String) async throws -> Community {
        return try await request(path: "/communities/\(pathSegment(id))")
    }

    func exchangeSession(proof: SessionExchangeProof) async throws -> SessionExchangeResponse {
        let body = SessionExchangeRequest(proof: proof)
        return try await request(path: "/auth/session/exchange", method: .POST, body: encode(body), requireAuth: false)
    }

    func currentUser() async throws -> User {
        return try await request(path: "/users/me")
    }

}

// MARK: - Feed
extension ApiClient {
    func homeFeed(cursor: String? = nil, locale: String? = nil, sort: String? = nil, timeRange: String? = nil) async throws -> HomeFeedResponse {
        var items: [URLQueryItem] = []
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let locale { items.append(URLQueryItem(name: "locale", value: locale)) }
        if let sort { items.append(URLQueryItem(name: "sort", value: sort)) }
        if let timeRange { items.append(URLQueryItem(name: "time_range", value: timeRange)) }
        return try await requestOptionalAuth(path: "/feed/home", queryItems: items.isEmpty ? nil : items)
    }

    func publicHomeFeed(cursor: String? = nil, locale: String? = nil, sort: String? = nil, timeRange: String? = nil) async throws -> HomeFeedResponse {
        var items: [URLQueryItem] = []
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let locale { items.append(URLQueryItem(name: "locale", value: locale)) }
        if let sort { items.append(URLQueryItem(name: "sort", value: sort)) }
        if let timeRange { items.append(URLQueryItem(name: "time_range", value: timeRange)) }
        return try await request(path: "/feed/home/public", queryItems: items.isEmpty ? nil : items, requireAuth: false)
    }
}

// MARK: - Communities
extension ApiClient {
    func community(id: String) async throws -> CommunityPreview {
        return try await request(path: "/communities/\(pathSegment(id))/preview")
    }

    func publicCommunity(id: String, locale: String? = nil) async throws -> CommunityPreview {
        var items: [URLQueryItem] = []
        if let locale { items.append(URLQueryItem(name: "locale", value: locale)) }
        return try await request(path: "/public-communities/\(pathSegment(id))", queryItems: items.isEmpty ? nil : items, requireAuth: false)
    }

    func communityPosts(communityId: String, cursor: String? = nil, sort: String? = nil, limit: Int? = nil, locale: String? = nil) async throws -> PostListResponse {
        var items: [URLQueryItem] = []
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let sort { items.append(URLQueryItem(name: "sort", value: sort)) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let locale { items.append(URLQueryItem(name: "locale", value: locale)) }
        return try await request(path: "/communities/\(pathSegment(communityId))/posts", queryItems: items.isEmpty ? nil : items)
    }

    func publicCommunityPosts(communityId: String, cursor: String? = nil, sort: String? = nil, limit: Int? = nil, locale: String? = nil) async throws -> PostListResponse {
        var items: [URLQueryItem] = []
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let sort { items.append(URLQueryItem(name: "sort", value: sort)) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let locale { items.append(URLQueryItem(name: "locale", value: locale)) }
        return try await request(path: "/public-communities/\(pathSegment(communityId))/posts", queryItems: items.isEmpty ? nil : items, requireAuth: false)
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

// MARK: - Posts
extension ApiClient {
    func authenticatedPost(id: String) async throws -> LocalizedPostResponse {
        return try await request(path: "/posts/\(pathSegment(id))")
    }

    func post(id: String) async throws -> LocalizedPostResponse {
        do {
            return try await authenticatedPost(id: id)
        } catch let error as ApiError where error.isAuthError || error.isNotFound {
            return try await publicPost(id: id)
        }
    }

    func publicPost(id: String) async throws -> LocalizedPostResponse {
        return try await request(path: "/public-posts/\(pathSegment(id))", requireAuth: false)
    }

    func votePost(id: String, value: Int, altchaPayload: String? = nil) async throws -> PostVoteResponse {
        return try await request(
            path: "/posts/\(pathSegment(id))/vote",
            method: .POST,
            body: encode(VoteRequest(value: value)),
            headers: altchaHeaders(altchaPayload)
        )
    }

    func createPost(communityId: String, body: CreatePostRequest, altchaPayload: String? = nil) async throws -> LocalizedPostResponse {
        return try await request(
            path: "/communities/\(pathSegment(communityId))/posts",
            method: .POST,
            body: encode(body),
            headers: altchaHeaders(altchaPayload)
        )
    }

    func linkPreview(communityId: String, url: String) async throws -> LinkPreviewResponse {
        return try await request(
            path: "/communities/\(pathSegment(communityId))/link-preview",
            queryItems: [URLQueryItem(name: "url", value: url)]
        )
    }
}

// MARK: - Comments
extension ApiClient {
    func comments(communityId: String, postId: String, cursor: String? = nil, sort: String? = nil, limit: Int? = nil) async throws -> CommentListResponse {
        var items: [URLQueryItem] = []
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let sort { items.append(URLQueryItem(name: "sort", value: sort)) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await request(path: "/communities/\(pathSegment(communityId))/posts/\(pathSegment(postId))/comments", queryItems: items.isEmpty ? nil : items)
    }

    func publicComments(postId: String, cursor: String? = nil, sort: String? = nil, limit: Int? = nil, locale: String? = nil) async throws -> CommentListResponse {
        var items: [URLQueryItem] = []
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let sort { items.append(URLQueryItem(name: "sort", value: sort)) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let locale { items.append(URLQueryItem(name: "locale", value: locale)) }
        return try await request(path: "/public-comments/posts/\(pathSegment(postId))/comments", queryItems: items.isEmpty ? nil : items, requireAuth: false)
    }

    func createComment(communityId: String, postId: String, body: CreateCommentRequest, altchaPayload: String? = nil) async throws {
        try await requestVoid(
            path: "/communities/\(pathSegment(communityId))/posts/\(pathSegment(postId))/comments",
            method: .POST,
            body: encode(body),
            headers: altchaHeaders(altchaPayload)
        )
    }

    func voteComment(id: String, value: Int, altchaPayload: String? = nil) async throws -> CommentVoteResponse {
        return try await request(
            path: "/comments/\(pathSegment(id))/vote",
            method: .POST,
            body: encode(VoteRequest(value: value)),
            headers: altchaHeaders(altchaPayload)
        )
    }

    func commentReplies(commentId: String, cursor: String? = nil, sort: String? = nil, limit: Int? = nil) async throws -> CommentListResponse {
        var items: [URLQueryItem] = []
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let sort { items.append(URLQueryItem(name: "sort", value: sort)) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await request(path: "/comments/\(pathSegment(commentId))/replies", queryItems: items.isEmpty ? nil : items)
    }

    func publicCommentReplies(commentId: String, cursor: String? = nil, sort: String? = nil, limit: Int? = nil, locale: String? = nil) async throws -> CommentListResponse {
        var items: [URLQueryItem] = []
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let sort { items.append(URLQueryItem(name: "sort", value: sort)) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let locale { items.append(URLQueryItem(name: "locale", value: locale)) }
        return try await request(path: "/public-comments/\(pathSegment(commentId))/replies", queryItems: items.isEmpty ? nil : items, requireAuth: false)
    }

    func createReply(commentId: String, body: CreateCommentRequest, altchaPayload: String? = nil) async throws {
        try await requestVoid(
            path: "/comments/\(pathSegment(commentId))/replies",
            method: .POST,
            body: encode(body),
            headers: altchaHeaders(altchaPayload)
        )
    }
}

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
        let request = makeRequest(
            path: "/profile-media",
            method: .POST,
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )

        let (responseData, response): (Data, URLResponse)
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw ApiError.networkError(.noConnection)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.serverError(statusCode: 0, message: "Invalid response", code: nil, retryable: false)
        }

        if httpResponse.statusCode == 401 {
            throw ApiError.unauthorized("Session expired")
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? jsonDecoder.decode(ErrorResponse.self, from: responseData) {
                throw ApiError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse.message ?? errorResponse.displayMessage,
                    code: errorResponse.code,
                    retryable: errorResponse.retryable ?? false,
                    details: errorResponse.details
                )
            }
            throw ApiError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Request failed with status \(httpResponse.statusCode)",
                code: nil,
                retryable: httpResponse.statusCode >= 500
            )
        }

        do {
            return try jsonDecoder.decode(ProfileMediaUploadResponse.self, from: responseData)
        } catch {
            throw ApiError.decodingError(Self.describeDecodingError(error))
        }
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
        let request = makeRequest(
            path: "/community-media",
            method: .POST,
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )

        let (responseData, response): (Data, URLResponse)
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw ApiError.networkError(.noConnection)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.serverError(statusCode: 0, message: "Invalid response", code: nil, retryable: false)
        }

        if httpResponse.statusCode == 401 {
            throw ApiError.unauthorized("Session expired")
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? jsonDecoder.decode(ErrorResponse.self, from: responseData) {
                throw ApiError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse.message ?? errorResponse.displayMessage,
                    code: errorResponse.code,
                    retryable: errorResponse.retryable ?? false,
                    details: errorResponse.details
                )
            }
            throw ApiError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Request failed with status \(httpResponse.statusCode)",
                code: nil,
                retryable: httpResponse.statusCode >= 500
            )
        }

        do {
            return try jsonDecoder.decode(ProfileMediaUploadResponse.self, from: responseData)
        } catch {
            throw ApiError.decodingError(Self.describeDecodingError(error))
        }
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
        var items = [URLQueryItem(name: "tab", value: tab)]
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let locale { items.append(URLQueryItem(name: "locale", value: locale)) }
        return try await request(path: path, queryItems: items, requireAuth: requireAuth)
    }
}

// MARK: - Notifications
extension ApiClient {
    func notificationSummary() async throws -> NotificationSummary {
        return try await request(path: "/notifications/summary")
    }

    func notificationTasks(cursor: String? = nil) async throws -> NotificationTasksResponse {
        var items: [URLQueryItem] = []
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await request(path: "/notifications/tasks", queryItems: items.isEmpty ? nil : items)
    }

    func notificationFeed(cursor: String? = nil, limit: Int? = nil) async throws -> NotificationFeedResponse {
        var items: [URLQueryItem] = []
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try await request(path: "/notifications/feed", queryItems: items.isEmpty ? nil : items)
    }

    func markNotificationsRead(eventIds: [String]? = nil) async throws {
        let body: Data?
        if let eventIds {
            body = encode(["event_ids": eventIds])
        } else {
            body = nil
        }
        try await requestVoid(path: "/notifications/mark-read", method: .POST, body: body)
    }

    func dismissTask(taskId: String) async throws {
        try await requestVoid(path: "/notifications/dismiss-task", method: .POST, body: encode(["task_id": taskId]))
    }
}

// MARK: - Onboarding
extension ApiClient {
    func onboardingStatus() async throws -> OnboardingStatus {
        return try await request(path: "/onboarding/status")
    }

    func dismissOnboarding() async throws {
        try await requestVoid(path: "/onboarding/dismiss", method: .POST)
    }
}

// MARK: - Verification
extension ApiClient {
    func createAltchaChallenge(scope: String, action: String) async throws -> AltchaChallenge {
        return try await request(
            path: "/verification/altcha/challenge",
            queryItems: [
                URLQueryItem(name: "scope", value: scope),
                URLQueryItem(name: "action", value: action)
            ]
        )
    }

    func refreshPassportWalletScore(communityId: String? = nil) async throws -> RefreshPassportWalletScoreResponse {
        return try await request(
            path: "/verification/passport-wallet-score",
            method: .POST,
            body: encode(RefreshPassportWalletScoreRequest(communityId: communityId))
        )
    }

    func startVerificationSession(sessionRequest: StartVerificationSessionRequest) async throws -> VerificationSession {
        return try await request(path: "/verification-sessions", method: .POST, body: encode(sessionRequest))
    }

    func verificationSession(id: String) async throws -> VerificationSession {
        return try await request(path: "/verification-sessions/\(pathSegment(id))")
    }

    func completeVerificationSession(id: String, request completeRequest: CompleteVerificationSessionRequest) async throws -> VerificationSession {
        return try await request(
            path: "/verification-sessions/\(pathSegment(id))/complete",
            method: .POST,
            body: encode(completeRequest)
        )
    }

    func startNamespaceSession(family: String, rootLabel: String) async throws -> NamespaceVerificationSession {
        let body = StartNamespaceVerificationSessionRequest(family: family, rootLabel: rootLabel)
        return try await request(path: "/namespace-verification-sessions", method: .POST, body: encode(body))
    }

    func namespaceSession(id: String) async throws -> NamespaceVerificationSession {
        return try await request(path: "/namespace-verification-sessions/\(pathSegment(id))")
    }

    func completeNamespaceSession(id: String, restartChallenge: Bool? = nil) async throws -> NamespaceVerificationSession {
        let body = CompleteNamespaceVerificationSessionRequest(restartChallenge: restartChallenge)
        return try await request(path: "/namespace-verification-sessions/\(pathSegment(id))/complete", method: .POST, body: encode(body))
    }
}
