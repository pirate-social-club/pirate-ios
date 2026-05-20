import Foundation

struct Comment: Codable, Identifiable {
    let commentId: String
    let communityId: String?
    let threadRootPostId: String?
    let parentCommentId: String?
    let authorUserId: String?
    let authorDisplayName: String?
    let authorAvatarRef: String?
    let authorIdentityMode: String?
    let authorAnonymousScope: String?
    let authorAnonymousLabel: String?
    let body: String?
    let status: String?
    let depth: Int?
    let directReplyCount: Int?
    let descendantCount: Int?
    let upvoteCount: Int?
    let downvoteCount: Int?
    let score: Int?
    let lastReplyAt: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case commentId = "comment_id"
        case id
        case comment
        case communityId = "community_id"
        case community
        case threadRootPostId = "thread_root_post_id"
        case threadRootPost = "thread_root_post"
        case parentCommentId = "parent_comment_id"
        case parentComment = "parent_comment"
        case authorUserId = "author_user_id"
        case authorUser = "author_user"
        case authorDisplayName = "author_display_name"
        case authorAvatarRef = "author_avatar_ref"
        case authorIdentityMode = "author_identity_mode"
        case identityMode = "identity_mode"
        case authorAnonymousScope = "author_anonymous_scope"
        case anonymousScope = "anonymous_scope"
        case authorAnonymousLabel = "author_anonymous_label"
        case anonymousLabel = "anonymous_label"
        case body, status, depth
        case directReplyCount = "direct_reply_count"
        case descendantCount = "descendant_count"
        case upvoteCount = "upvote_count"
        case downvoteCount = "downvote_count"
        case score
        case lastReplyAt = "last_reply_at"
        case createdAt = "created_at"
        case created
        case updatedAt = "updated_at"
        case updated
    }

    var id: String { commentId }

    var authorAvatarURL: URL? {
        guard let ref = authorAvatarRef else { return nil }
        return URL(string: ref)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.commentId = container.decodeLossyStringIfPresent(forKey: .commentId)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
            ?? container.decodeLossyStringIfPresent(forKey: .comment)
            ?? ""
        self.communityId = container.decodeLossyStringIfPresent(forKey: .communityId)
            ?? container.decodeLossyStringIfPresent(forKey: .community)
        self.threadRootPostId = container.decodeLossyStringIfPresent(forKey: .threadRootPostId)
            ?? container.decodeLossyStringIfPresent(forKey: .threadRootPost)
        self.parentCommentId = container.decodeLossyStringIfPresent(forKey: .parentCommentId)
            ?? container.decodeLossyStringIfPresent(forKey: .parentComment)
        self.authorUserId = container.decodeLossyStringIfPresent(forKey: .authorUserId)
            ?? container.decodeLossyStringIfPresent(forKey: .authorUser)
        self.authorDisplayName = container.decodeLossyStringIfPresent(forKey: .authorDisplayName)
        self.authorAvatarRef = container.decodeLossyStringIfPresent(forKey: .authorAvatarRef)
        self.authorIdentityMode = container.decodeLossyStringIfPresent(forKey: .authorIdentityMode)
            ?? container.decodeLossyStringIfPresent(forKey: .identityMode)
        self.authorAnonymousScope = container.decodeLossyStringIfPresent(forKey: .authorAnonymousScope)
            ?? container.decodeLossyStringIfPresent(forKey: .anonymousScope)
        self.authorAnonymousLabel = container.decodeLossyStringIfPresent(forKey: .authorAnonymousLabel)
            ?? container.decodeLossyStringIfPresent(forKey: .anonymousLabel)
        self.body = container.decodeLossyStringIfPresent(forKey: .body)
        self.status = container.decodeLossyStringIfPresent(forKey: .status)
        self.depth = container.decodeLossyIntIfPresent(forKey: .depth)
        self.directReplyCount = container.decodeLossyIntIfPresent(forKey: .directReplyCount)
        self.descendantCount = container.decodeLossyIntIfPresent(forKey: .descendantCount)
        self.upvoteCount = container.decodeLossyIntIfPresent(forKey: .upvoteCount)
        self.downvoteCount = container.decodeLossyIntIfPresent(forKey: .downvoteCount)
        self.score = container.decodeLossyIntIfPresent(forKey: .score)
        self.lastReplyAt = container.decodeLossyStringIfPresent(forKey: .lastReplyAt)
        self.createdAt = container.decodeLossyStringIfPresent(forKey: .createdAt)
            ?? container.decodeLossyStringIfPresent(forKey: .created)
        self.updatedAt = container.decodeLossyStringIfPresent(forKey: .updatedAt)
            ?? container.decodeLossyStringIfPresent(forKey: .updated)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(commentId, forKey: .commentId)
        try container.encodeIfPresent(communityId, forKey: .communityId)
        try container.encodeIfPresent(threadRootPostId, forKey: .threadRootPostId)
        try container.encodeIfPresent(parentCommentId, forKey: .parentCommentId)
        try container.encodeIfPresent(authorUserId, forKey: .authorUserId)
        try container.encodeIfPresent(authorDisplayName, forKey: .authorDisplayName)
        try container.encodeIfPresent(authorAvatarRef, forKey: .authorAvatarRef)
        try container.encodeIfPresent(authorIdentityMode, forKey: .authorIdentityMode)
        try container.encodeIfPresent(authorAnonymousScope, forKey: .authorAnonymousScope)
        try container.encodeIfPresent(authorAnonymousLabel, forKey: .authorAnonymousLabel)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(depth, forKey: .depth)
        try container.encodeIfPresent(directReplyCount, forKey: .directReplyCount)
        try container.encodeIfPresent(descendantCount, forKey: .descendantCount)
        try container.encodeIfPresent(upvoteCount, forKey: .upvoteCount)
        try container.encodeIfPresent(downvoteCount, forKey: .downvoteCount)
        try container.encodeIfPresent(score, forKey: .score)
        try container.encodeIfPresent(lastReplyAt, forKey: .lastReplyAt)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct CommentListItem: Codable, Identifiable {
    let comment: Comment
    let viewerVote: Int?
    let resolvedLocale: String?
    let translationState: String?
    let machineTranslated: Bool?
    let translatedBody: String?
    let sourceHash: String?

    enum CodingKeys: String, CodingKey {
        case comment
        case viewerVote = "viewer_vote"
        case resolvedLocale = "resolved_locale"
        case translationState = "translation_state"
        case machineTranslated = "machine_translated"
        case translatedBody = "translated_body"
        case sourceHash = "source_hash"
    }

    var id: String { comment.id }
}

struct CommentListResponse: Codable {
    let items: [CommentListItem]
    let nextCursor: String?
    let threadSnapshot: [CommentListItem]?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
        case threadSnapshot = "thread_snapshot"
    }
}

struct CommentVoteResponse: Codable {
    let id: String
    let value: Int

    enum CodingKeys: String, CodingKey {
        case id = "comment"
        case value
    }
}

struct CreateCommentRequest: Codable {
    let body: String
    let identityMode: String?

    enum CodingKeys: String, CodingKey {
        case body
        case identityMode = "identity_mode"
    }
}
