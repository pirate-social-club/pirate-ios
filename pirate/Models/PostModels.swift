import Foundation

struct Post: Codable, Identifiable {
    let postId: String
    let communityId: String?
    let title: String?
    let body: String?
    let caption: String?
    let linkUrl: String?
    let linkTitle: String?
    let linkDescription: String?
    let linkImage: String?
    let embeds: [JSONValue]?
    let mediaRefs: [MediaRef]?
    let postType: String?
    let status: String?
    let visibility: String?
    let authorUserId: String?
    let authorDisplayName: String?
    let authorAvatarRef: String?
    let authorIdentityMode: String?
    let authorAnonymousScope: String?
    let authorAnonymousLabel: String?
    let sourceLanguage: String?
    let translationPolicy: String?
    let accessMode: String?
    let asset: String?
    let anchorLiveRoom: String?
    let anchorLiveRoomStatus: String?
    let songArtifactBundle: String?
    let songTitle: String?
    let songAnnotationsURL: String?
    let songMode: String?
    let rightsBasis: String?
    let upstreamAssetRefs: [String]?
    let analysisState: String?
    let contentSafetyState: String?
    let ageGatePolicy: String?
    let flairId: String?
    let score: Int?
    let upvoteCount: Int?
    let downvoteCount: Int?
    let commentCount: Int?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case id
        case post
        case communityId = "community_id"
        case community
        case title, body, caption
        case linkUrl = "link_url"
        case linkTitle = "link_title"
        case linkOgTitle = "link_og_title"
        case linkDescription = "link_description"
        case linkOgDescription = "link_og_description"
        case linkImage = "link_image"
        case linkOgImage = "link_og_image_url"
        case linkOgImageLegacy = "link_og_image"
        case ogImage = "og_image"
        case embeds
        case mediaRefs = "media_refs"
        case postType = "post_type"
        case status, visibility
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
        case sourceLanguage = "source_language"
        case translationPolicy = "translation_policy"
        case accessMode = "access_mode"
        case asset
        case anchorLiveRoom = "anchor_live_room"
        case anchorLiveRoomStatus = "anchor_live_room_status"
        case songArtifactBundle = "song_artifact_bundle"
        case songTitle = "song_title"
        case songAnnotationsURL = "song_annotations_url"
        case songMode = "song_mode"
        case rightsBasis = "rights_basis"
        case upstreamAssetRefs = "upstream_asset_refs"
        case analysisState = "analysis_state"
        case contentSafetyState = "content_safety_state"
        case ageGatePolicy = "age_gate_policy"
        case flairId = "flair_id"
        case labelId = "label_id"
        case score
        case upvoteCount = "upvote_count"
        case downvoteCount = "downvote_count"
        case commentCount = "comment_count"
        case createdAt = "created_at"
        case created
        case updatedAt = "updated_at"
        case updated
    }

    var id: String { postId }

    var authorAvatarURL: URL? {
        guard let ref = authorAvatarRef else { return nil }
        return URL(string: ref)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.postId = container.decodeLossyStringIfPresent(forKey: .postId)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
            ?? container.decodeLossyStringIfPresent(forKey: .post)
            ?? ""
        self.communityId = container.decodeLossyStringIfPresent(forKey: .communityId)
            ?? container.decodeLossyStringIfPresent(forKey: .community)
        self.title = container.decodeLossyStringIfPresent(forKey: .title)
        self.body = container.decodeLossyStringIfPresent(forKey: .body)
        self.caption = container.decodeLossyStringIfPresent(forKey: .caption)
        self.linkUrl = container.decodeLossyStringIfPresent(forKey: .linkUrl)
        self.linkTitle = container.decodeLossyStringIfPresent(forKey: .linkTitle)
            ?? container.decodeLossyStringIfPresent(forKey: .linkOgTitle)
        self.linkDescription = container.decodeLossyStringIfPresent(forKey: .linkDescription)
            ?? container.decodeLossyStringIfPresent(forKey: .linkOgDescription)
        self.linkImage = container.decodeLossyStringIfPresent(forKey: .linkImage)
            ?? container.decodeLossyStringIfPresent(forKey: .linkOgImage)
            ?? container.decodeLossyStringIfPresent(forKey: .linkOgImageLegacy)
            ?? container.decodeLossyStringIfPresent(forKey: .ogImage)
        self.embeds = try? container.decodeIfPresent([JSONValue].self, forKey: .embeds)
        self.mediaRefs = try? container.decodeIfPresent([MediaRef].self, forKey: .mediaRefs)
        self.postType = container.decodeLossyStringIfPresent(forKey: .postType)
        self.status = container.decodeLossyStringIfPresent(forKey: .status)
        self.visibility = container.decodeLossyStringIfPresent(forKey: .visibility)
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
        self.sourceLanguage = container.decodeLossyStringIfPresent(forKey: .sourceLanguage)
        self.translationPolicy = container.decodeLossyStringIfPresent(forKey: .translationPolicy)
        self.accessMode = container.decodeLossyStringIfPresent(forKey: .accessMode)
        self.asset = container.decodeLossyStringIfPresent(forKey: .asset)
        self.anchorLiveRoom = container.decodeLossyStringIfPresent(forKey: .anchorLiveRoom)
        self.anchorLiveRoomStatus = container.decodeLossyStringIfPresent(forKey: .anchorLiveRoomStatus)
        self.songArtifactBundle = container.decodeLossyStringIfPresent(forKey: .songArtifactBundle)
        self.songTitle = container.decodeLossyStringIfPresent(forKey: .songTitle)
        self.songAnnotationsURL = container.decodeLossyStringIfPresent(forKey: .songAnnotationsURL)
        self.songMode = container.decodeLossyStringIfPresent(forKey: .songMode)
        self.rightsBasis = container.decodeLossyStringIfPresent(forKey: .rightsBasis)
        self.upstreamAssetRefs = try? container.decodeIfPresent([String].self, forKey: .upstreamAssetRefs)
        self.analysisState = container.decodeLossyStringIfPresent(forKey: .analysisState)
        self.contentSafetyState = container.decodeLossyStringIfPresent(forKey: .contentSafetyState)
        self.ageGatePolicy = container.decodeLossyStringIfPresent(forKey: .ageGatePolicy)
        self.flairId = container.decodeLossyStringIfPresent(forKey: .flairId)
            ?? container.decodeLossyStringIfPresent(forKey: .labelId)
        self.score = container.decodeLossyIntIfPresent(forKey: .score)
        self.upvoteCount = container.decodeLossyIntIfPresent(forKey: .upvoteCount)
        self.downvoteCount = container.decodeLossyIntIfPresent(forKey: .downvoteCount)
        self.commentCount = container.decodeLossyIntIfPresent(forKey: .commentCount)
        self.createdAt = container.decodeLossyStringIfPresent(forKey: .createdAt)
            ?? container.decodeLossyStringIfPresent(forKey: .created)
        self.updatedAt = container.decodeLossyStringIfPresent(forKey: .updatedAt)
            ?? container.decodeLossyStringIfPresent(forKey: .updated)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(postId, forKey: .postId)
        try container.encodeIfPresent(communityId, forKey: .communityId)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(caption, forKey: .caption)
        try container.encodeIfPresent(linkUrl, forKey: .linkUrl)
        try container.encodeIfPresent(linkTitle, forKey: .linkTitle)
        try container.encodeIfPresent(linkDescription, forKey: .linkDescription)
        try container.encodeIfPresent(linkImage, forKey: .linkImage)
        try container.encodeIfPresent(embeds, forKey: .embeds)
        try container.encodeIfPresent(mediaRefs, forKey: .mediaRefs)
        try container.encodeIfPresent(postType, forKey: .postType)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(visibility, forKey: .visibility)
        try container.encodeIfPresent(authorUserId, forKey: .authorUserId)
        try container.encodeIfPresent(authorDisplayName, forKey: .authorDisplayName)
        try container.encodeIfPresent(authorAvatarRef, forKey: .authorAvatarRef)
        try container.encodeIfPresent(authorIdentityMode, forKey: .authorIdentityMode)
        try container.encodeIfPresent(authorAnonymousScope, forKey: .authorAnonymousScope)
        try container.encodeIfPresent(authorAnonymousLabel, forKey: .authorAnonymousLabel)
        try container.encodeIfPresent(sourceLanguage, forKey: .sourceLanguage)
        try container.encodeIfPresent(translationPolicy, forKey: .translationPolicy)
        try container.encodeIfPresent(accessMode, forKey: .accessMode)
        try container.encodeIfPresent(asset, forKey: .asset)
        try container.encodeIfPresent(anchorLiveRoom, forKey: .anchorLiveRoom)
        try container.encodeIfPresent(anchorLiveRoomStatus, forKey: .anchorLiveRoomStatus)
        try container.encodeIfPresent(songArtifactBundle, forKey: .songArtifactBundle)
        try container.encodeIfPresent(songTitle, forKey: .songTitle)
        try container.encodeIfPresent(songAnnotationsURL, forKey: .songAnnotationsURL)
        try container.encodeIfPresent(songMode, forKey: .songMode)
        try container.encodeIfPresent(rightsBasis, forKey: .rightsBasis)
        try container.encodeIfPresent(upstreamAssetRefs, forKey: .upstreamAssetRefs)
        try container.encodeIfPresent(analysisState, forKey: .analysisState)
        try container.encodeIfPresent(contentSafetyState, forKey: .contentSafetyState)
        try container.encodeIfPresent(ageGatePolicy, forKey: .ageGatePolicy)
        try container.encodeIfPresent(flairId, forKey: .flairId)
        try container.encodeIfPresent(score, forKey: .score)
        try container.encodeIfPresent(upvoteCount, forKey: .upvoteCount)
        try container.encodeIfPresent(downvoteCount, forKey: .downvoteCount)
        try container.encodeIfPresent(commentCount, forKey: .commentCount)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
}

struct MediaRef: Codable {
    let mediaKey: String?
    let mediaType: String?
    let mediaUrl: String?
    let storageRef: String?
    let mimeType: String?
    let sizeBytes: Int?
    let width: Int?
    let height: Int?
    let durationMs: Int?
    let posterRef: String?
    let posterMimeType: String?
    let posterWidth: Int?
    let posterHeight: Int?

    enum CodingKeys: String, CodingKey {
        case mediaKey = "media_key"
        case mediaType = "media_type"
        case mediaUrl = "media_url"
        case storageRef = "storage_ref"
        case mimeType = "mime_type"
        case sizeBytes = "size_bytes"
        case width
        case height
        case durationMs = "duration_ms"
        case posterRef = "poster_ref"
        case posterMimeType = "poster_mime_type"
        case posterWidth = "poster_width"
        case posterHeight = "poster_height"
    }

    init(
        mediaKey: String? = nil,
        mediaType: String? = nil,
        mediaUrl: String? = nil,
        storageRef: String? = nil,
        mimeType: String? = nil,
        sizeBytes: Int? = nil,
        width: Int? = nil,
        height: Int? = nil,
        durationMs: Int? = nil,
        posterRef: String? = nil,
        posterMimeType: String? = nil,
        posterWidth: Int? = nil,
        posterHeight: Int? = nil
    ) {
        self.mediaKey = mediaKey
        self.mediaType = mediaType
        self.mediaUrl = mediaUrl
        self.storageRef = storageRef
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.width = width
        self.height = height
        self.durationMs = durationMs
        self.posterRef = posterRef
        self.posterMimeType = posterMimeType
        self.posterWidth = posterWidth
        self.posterHeight = posterHeight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.mediaKey = container.decodeLossyStringIfPresent(forKey: .mediaKey)
        self.mediaType = container.decodeLossyStringIfPresent(forKey: .mediaType)
        self.mediaUrl = container.decodeLossyStringIfPresent(forKey: .mediaUrl)
        self.storageRef = container.decodeLossyStringIfPresent(forKey: .storageRef)
        self.mimeType = container.decodeLossyStringIfPresent(forKey: .mimeType)
        self.sizeBytes = container.decodeLossyIntIfPresent(forKey: .sizeBytes)
        self.width = container.decodeLossyIntIfPresent(forKey: .width)
        self.height = container.decodeLossyIntIfPresent(forKey: .height)
        self.durationMs = container.decodeLossyIntIfPresent(forKey: .durationMs)
        self.posterRef = container.decodeLossyStringIfPresent(forKey: .posterRef)
        self.posterMimeType = container.decodeLossyStringIfPresent(forKey: .posterMimeType)
        self.posterWidth = container.decodeLossyIntIfPresent(forKey: .posterWidth)
        self.posterHeight = container.decodeLossyIntIfPresent(forKey: .posterHeight)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(mediaKey, forKey: .mediaKey)
        try container.encodeIfPresent(mediaType, forKey: .mediaType)
        try container.encodeIfPresent(mediaUrl, forKey: .mediaUrl)
        try container.encodeIfPresent(storageRef, forKey: .storageRef)
        try container.encodeIfPresent(mimeType, forKey: .mimeType)
        try container.encodeIfPresent(sizeBytes, forKey: .sizeBytes)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(durationMs, forKey: .durationMs)
        try container.encodeIfPresent(posterRef, forKey: .posterRef)
        try container.encodeIfPresent(posterMimeType, forKey: .posterMimeType)
        try container.encodeIfPresent(posterWidth, forKey: .posterWidth)
        try container.encodeIfPresent(posterHeight, forKey: .posterHeight)
    }
}

struct LocalizedPostResponse: Codable, Identifiable {
    let post: Post
    let threadSnapshot: [CommentListItem]?
    let songPresentation: SongPresentation?
    let commentCount: Int?
    let upvoteCount: Int?
    let downvoteCount: Int?
    let likeCount: Int?
    let viewerVote: Int?
    let viewerIsAuthor: Bool?
    let authorCommunityRole: String?
    let ageGateViewerState: String?
    let locale: String?
    let flair: String?
    let translationState: String?
    let machineTranslated: Bool?
    let translatedTitle: String?
    let translatedBody: String?
    let translatedCaption: String?
    let sourceHash: String?

    enum CodingKeys: String, CodingKey {
        case post
        case threadSnapshot = "thread_snapshot"
        case songPresentation = "song_presentation"
        case commentCount = "comment_count"
        case upvoteCount = "upvote_count"
        case downvoteCount = "downvote_count"
        case likeCount = "like_count"
        case viewerVote = "viewer_vote"
        case viewerIsAuthor = "viewer_is_author"
        case authorCommunityRole = "author_community_role"
        case ageGateViewerState = "age_gate_viewer_state"
        case locale, flair
        case resolvedLocale = "resolved_locale"
        case translationState = "translation_state"
        case machineTranslated = "machine_translated"
        case translatedTitle = "translated_title"
        case translatedBody = "translated_body"
        case translatedCaption = "translated_caption"
        case sourceHash = "source_hash"
    }

    var id: String { post.id }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.post = try container.decode(Post.self, forKey: .post)
        self.threadSnapshot = try? container.decodeIfPresent([CommentListItem].self, forKey: .threadSnapshot)
        self.songPresentation = try? container.decodeIfPresent(SongPresentation.self, forKey: .songPresentation)
        self.commentCount = container.decodeLossyIntIfPresent(forKey: .commentCount)
        self.upvoteCount = container.decodeLossyIntIfPresent(forKey: .upvoteCount)
        self.downvoteCount = container.decodeLossyIntIfPresent(forKey: .downvoteCount)
        self.likeCount = container.decodeLossyIntIfPresent(forKey: .likeCount)
        self.viewerVote = container.decodeLossyIntIfPresent(forKey: .viewerVote)
        self.viewerIsAuthor = container.decodeLossyBoolIfPresent(forKey: .viewerIsAuthor)
        self.authorCommunityRole = container.decodeLossyStringIfPresent(forKey: .authorCommunityRole)
        self.ageGateViewerState = container.decodeLossyStringIfPresent(forKey: .ageGateViewerState)
        self.locale = container.decodeLossyStringIfPresent(forKey: .locale)
            ?? container.decodeLossyStringIfPresent(forKey: .resolvedLocale)
        self.flair = container.decodeLossyStringIfPresent(forKey: .flair)
        self.translationState = container.decodeLossyStringIfPresent(forKey: .translationState)
        self.machineTranslated = container.decodeLossyBoolIfPresent(forKey: .machineTranslated)
        self.translatedTitle = container.decodeLossyStringIfPresent(forKey: .translatedTitle)
        self.translatedBody = container.decodeLossyStringIfPresent(forKey: .translatedBody)
        self.translatedCaption = container.decodeLossyStringIfPresent(forKey: .translatedCaption)
        self.sourceHash = container.decodeLossyStringIfPresent(forKey: .sourceHash)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(post, forKey: .post)
        try container.encodeIfPresent(threadSnapshot, forKey: .threadSnapshot)
        try container.encodeIfPresent(songPresentation, forKey: .songPresentation)
        try container.encodeIfPresent(commentCount, forKey: .commentCount)
        try container.encodeIfPresent(upvoteCount, forKey: .upvoteCount)
        try container.encodeIfPresent(downvoteCount, forKey: .downvoteCount)
        try container.encodeIfPresent(likeCount, forKey: .likeCount)
        try container.encodeIfPresent(viewerVote, forKey: .viewerVote)
        try container.encodeIfPresent(viewerIsAuthor, forKey: .viewerIsAuthor)
        try container.encodeIfPresent(authorCommunityRole, forKey: .authorCommunityRole)
        try container.encodeIfPresent(ageGateViewerState, forKey: .ageGateViewerState)
        try container.encodeIfPresent(locale, forKey: .locale)
        try container.encodeIfPresent(flair, forKey: .flair)
        try container.encodeIfPresent(translationState, forKey: .translationState)
        try container.encodeIfPresent(machineTranslated, forKey: .machineTranslated)
        try container.encodeIfPresent(translatedTitle, forKey: .translatedTitle)
        try container.encodeIfPresent(translatedBody, forKey: .translatedBody)
        try container.encodeIfPresent(translatedCaption, forKey: .translatedCaption)
        try container.encodeIfPresent(sourceHash, forKey: .sourceHash)
    }
}

struct HomeFeedItem: Codable, Identifiable {
    let community: HomeFeedCommunitySummary
    let post: LocalizedPostResponse

    var id: String { post.id }
}

struct HomeFeedResponse: Codable {
    let items: [HomeFeedItem]
    let topCommunities: [HomeFeedCommunitySummary]?
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case topCommunities = "top_communities"
        case nextCursor = "next_cursor"
    }
}

struct HomeFeedCommunitySummary: Codable, Identifiable {
    let communityId: String
    let displayName: String
    let routeSlug: String?
    let avatarRef: String?
    let memberCount: Int?
    let followerCount: Int?
    let viewerFollowing: Bool?

    enum CodingKeys: String, CodingKey {
        case communityId = "community_id"
        case id
        case community
        case displayName = "display_name"
        case routeSlug = "route_slug"
        case avatarRef = "avatar_ref"
        case memberCount = "member_count"
        case followerCount = "follower_count"
        case viewerFollowing = "viewer_following"
    }

    var id: String { communityId }

    var avatarURL: URL? {
        guard let ref = avatarRef else { return nil }
        return URL(string: ref)
    }

    init(
        communityId: String,
        displayName: String,
        routeSlug: String? = nil,
        avatarRef: String? = nil,
        memberCount: Int? = nil,
        followerCount: Int? = nil,
        viewerFollowing: Bool? = nil
    ) {
        self.communityId = communityId
        self.displayName = displayName
        self.routeSlug = routeSlug
        self.avatarRef = avatarRef
        self.memberCount = memberCount
        self.followerCount = followerCount
        self.viewerFollowing = viewerFollowing
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.communityId = container.decodeLossyStringIfPresent(forKey: .communityId)
            ?? container.decodeLossyStringIfPresent(forKey: .id)
            ?? container.decodeLossyStringIfPresent(forKey: .community)
            ?? ""
        self.displayName = container.decodeLossyStringIfPresent(forKey: .displayName) ?? "Community"
        self.routeSlug = container.decodeLossyStringIfPresent(forKey: .routeSlug)
        self.avatarRef = container.decodeLossyStringIfPresent(forKey: .avatarRef)
        self.memberCount = container.decodeLossyIntIfPresent(forKey: .memberCount)
        self.followerCount = container.decodeLossyIntIfPresent(forKey: .followerCount)
        self.viewerFollowing = container.decodeLossyBoolIfPresent(forKey: .viewerFollowing)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(communityId, forKey: .communityId)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(routeSlug, forKey: .routeSlug)
        try container.encodeIfPresent(avatarRef, forKey: .avatarRef)
        try container.encodeIfPresent(memberCount, forKey: .memberCount)
        try container.encodeIfPresent(followerCount, forKey: .followerCount)
        try container.encodeIfPresent(viewerFollowing, forKey: .viewerFollowing)
    }
}

struct PostVoteResponse: Codable {
    let id: String
    let value: Int

    enum CodingKeys: String, CodingKey {
        case id = "post"
        case value
    }
}

struct CreatePostRequest: Codable {
    let idempotencyKey: String?
    let title: String?
    let body: String?
    let caption: String?
    let postType: String?
    let linkUrl: String?
    let mediaRefs: [MediaRef]?
    let ageGatePolicy: String?
    let flairId: String?
    let identityMode: String?
    let anonymousScope: String?
    let disclosedQualifierIds: [String]?
    let translationPolicy: String?
    let visibility: String?

    enum CodingKeys: String, CodingKey {
        case idempotencyKey = "idempotency_key"
        case title, body, caption
        case postType = "post_type"
        case linkUrl = "link_url"
        case mediaRefs = "media_refs"
        case ageGatePolicy = "age_gate_policy"
        case flairId = "flair_id"
        case identityMode = "identity_mode"
        case anonymousScope = "anonymous_scope"
        case disclosedQualifierIds = "disclosed_qualifier_ids"
        case translationPolicy = "translation_policy"
        case visibility
    }

    init(
        idempotencyKey: String? = nil,
        title: String? = nil,
        body: String? = nil,
        caption: String? = nil,
        postType: String? = nil,
        linkUrl: String? = nil,
        mediaRefs: [MediaRef]? = nil,
        ageGatePolicy: String? = nil,
        flairId: String? = nil,
        identityMode: String? = nil,
        anonymousScope: String? = nil,
        disclosedQualifierIds: [String]? = nil,
        translationPolicy: String? = nil,
        visibility: String? = nil
    ) {
        self.idempotencyKey = idempotencyKey
        self.title = title
        self.body = body
        self.caption = caption
        self.postType = postType
        self.linkUrl = linkUrl
        self.mediaRefs = mediaRefs
        self.ageGatePolicy = ageGatePolicy
        self.flairId = flairId
        self.identityMode = identityMode
        self.anonymousScope = anonymousScope
        self.disclosedQualifierIds = disclosedQualifierIds
        self.translationPolicy = translationPolicy
        self.visibility = visibility
    }
}

struct LinkPreviewResponse: Codable {
    let kind: String?
    let provider: String?
    let canonicalUrl: String?
    let originalUrl: String?
    let state: String?
    let title: String?
    let imageUrl: String?
    let preview: [String: JSONValue]?
    let oembedHtml: String?
    let oembedCacheAge: Int?

    enum CodingKeys: String, CodingKey {
        case kind, provider, state, title, preview
        case canonicalUrl = "canonical_url"
        case originalUrl = "original_url"
        case imageUrl = "image_url"
        case oembedHtml = "oembed_html"
        case oembedCacheAge = "oembed_cache_age"
    }
}

struct VoteRequest: Codable {
    let value: Int
}

struct PostListResponse: Codable {
    let items: [LocalizedPostResponse]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}
