import Foundation

// MARK: - Comments
extension ApiClient {
    func comments(communityId: String, postId: String, cursor: String? = nil, sort: String? = nil, limit: Int? = nil) async throws -> CommentListResponse {
        return try await request(path: "/communities/\(pathSegment(communityId))/posts/\(pathSegment(postId))/comments", queryItems: listQueryItems(cursor: cursor, sort: sort, limit: limit))
    }

    func publicComments(postId: String, cursor: String? = nil, sort: String? = nil, limit: Int? = nil, locale: String? = nil) async throws -> CommentListResponse {
        return try await request(path: "/public-comments/posts/\(pathSegment(postId))/comments", queryItems: listQueryItems(cursor: cursor, sort: sort, limit: limit, locale: locale), requireAuth: false)
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
        return try await request(path: "/comments/\(pathSegment(commentId))/replies", queryItems: listQueryItems(cursor: cursor, sort: sort, limit: limit))
    }

    func publicCommentReplies(commentId: String, cursor: String? = nil, sort: String? = nil, limit: Int? = nil, locale: String? = nil) async throws -> CommentListResponse {
        return try await request(path: "/public-comments/\(pathSegment(commentId))/replies", queryItems: listQueryItems(cursor: cursor, sort: sort, limit: limit, locale: locale), requireAuth: false)
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
