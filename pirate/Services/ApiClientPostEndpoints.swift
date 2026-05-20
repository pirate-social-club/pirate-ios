import Foundation

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
