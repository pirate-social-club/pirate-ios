import SwiftUI

private enum PostReadMode {
    case authenticated
    case publicRead
}

struct PostView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    @Environment(\.dismiss) private var dismiss
    var sessionManager: SessionManager

    let postId: String

    @State private var post: LocalizedPostResponse?
    @State private var communityPreview: CommunityPreview?
    @State private var comments: [CommentListItem] = []
    @State private var nextCursor: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSignIn = false
    @State private var newComment = ""
    @State private var isSubmittingComment = false
    @State private var actionError: String?
    @State private var commentSort = "best"
    @State private var isLoadingMoreComments = false
    @State private var replyingToCommentId: String?
    @State private var replyDrafts: [String: String] = [:]
    @State private var submittingReplyIds: Set<String> = []
    @State private var expandedReplyIds: Set<String> = []
    @State private var repliesByCommentId: [String: [CommentListItem]] = [:]
    @State private var nextReplyCursorByCommentId: [String: String] = [:]
    @State private var loadingReplyIds: Set<String> = []
    @State private var votingCommentIds: Set<String> = []
    @State private var liveRoomAccess: LiveRoomAccessResponse?
    @State private var liveRoomAccessError: String?
    @State private var isLoadingLiveRoomAccess = false
    @State private var isAttachingLiveRoom = false
    @State private var liveViewerSession: LiveRoomViewerAttachResponse?
    @State private var readMode: PostReadMode = .publicRead
    @State private var isVotingPost = false

    private var usesAuthenticatedRead: Bool {
        sessionManager.isAuthenticated && readMode == .authenticated
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let post {
                    postContent(post)
                    Divider().overlay(colors.borderSoft).padding(.vertical, 8)
                    commentsSection
                } else if isLoading {
                    LoadingView()
                } else if let error = errorMessage {
                    ErrorView(message: error, retry: loadPost)
                }
            }
            .padding(.horizontal, PirateTokens.pageGutter)
        }
        .background(colors.bgPage)
        .navigationTitle("Post")
        .inlineNavigationBarTitle()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    PirateIconView(icon: .x, size: 22, color: colors.textPrimary)
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("Close post")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Best") { changeCommentSort("best") }
                    Button("New") { changeCommentSort("new") }
                    Button("Top") { changeCommentSort("top") }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(colors.textSecondary)
                }
            }
        }
        .task {
            await loadPost()
        }
        .task(id: post?.post.anchorLiveRoom) {
            await pollLiveRoomAccess()
        }
        .sheet(isPresented: $showSignIn) {
            SignInDrawer(sessionManager: sessionManager, isPresented: $showSignIn)
        }
        .fullScreenCover(isPresented: Binding(
            get: { liveViewerSession != nil },
            set: { isPresented in
                if !isPresented {
                    liveViewerSession = nil
                }
            }
        )) {
            if let liveViewerSession {
                LiveRoomViewerView(
                    attachResponse: liveViewerSession,
                    onRenew: renewLiveRoomViewer
                )
            }
        }
    }

    private func postContent(_ localizedPost: LocalizedPostResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            postAuthorHeader(localizedPost.post)

            if let title = localizedPost.post.title {
                Text(title)
                    .font(PirateTokens.Typography.h3)
                    .foregroundStyle(colors.textPrimary)
            }

            if let body = localizedPost.post.body, !body.isEmpty {
                Text(body)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textPrimary)
            }

            let mediaItem = PiratePostMediaItem.primary(for: localizedPost.post)
            if mediaItem != nil {
                PostMediaView(post: localizedPost.post, context: .detail)
            }

            if localizedPost.post.linkUrl != nil {
                PostLinkPreview(post: localizedPost.post, compact: false, showsPreviewImage: mediaItem == nil)
            }

            if localizedPost.post.anchorLiveRoom != nil {
                LiveRoomBannerView(
                    post: localizedPost.post,
                    accessResponse: liveRoomAccess,
                    isLoading: isLoadingLiveRoomAccess,
                    isAttaching: isAttachingLiveRoom,
                    errorMessage: liveRoomAccessError,
                    onRefresh: {
                        Task { await loadLiveRoomAccess(for: localizedPost.post) }
                    },
                    onWatch: {
                        Task { await attachLiveRoomViewer(for: localizedPost.post) }
                    },
                    onBuyTicket: {
                        liveRoomAccessError = "Ticket checkout is not available in the iOS app yet."
                    },
                    onSignIn: {
                        showSignIn = true
                    }
                )
            }

            postEngagementBar(localizedPost)
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func postAuthorHeader(_ post: Post) -> some View {
        if let route = authorProfileRoute(for: post) {
            NavigationLink(value: route) {
                postAuthorHeaderContent(post)
            }
            .buttonStyle(.plain)
        } else {
            postAuthorHeaderContent(post)
        }
    }

    private func postAuthorHeaderContent(_ post: Post) -> some View {
        let label = authorLabel(for: post)
        let time = post.createdAt.map(relativeTime).flatMap { $0.isEmpty ? nil : $0 }
        return HStack(spacing: 10) {
            AvatarView(avatarRef: post.authorAvatarRef, size: 38, fallbackLabel: label, fallbackSeed: post.authorUserId ?? label)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(PirateTokens.Typography.smallStrong)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)

                if let time {
                    Text(time)
                        .font(PirateTokens.Typography.small)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityLabel("View \(label) profile")
    }

    private func postEngagementBar(_ post: LocalizedPostResponse) -> some View {
        HStack(spacing: 10) {
            VotePill(
                score: postScore(post),
                voteValue: post.viewerVote,
                disabled: isVotingPost,
                onVote: { value in
                    Task { await voteOnPost(value) }
                }
            )

            CommentCountPill(count: post.commentCount ?? post.post.commentCount ?? 0)

            Spacer()
        }
        .padding(.top, 4)
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments")
                .font(PirateTokens.Typography.h4)
                .foregroundStyle(colors.textPrimary)

            commentComposer

            if let actionError {
                Text(actionError)
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.accentDanger)
            }

            ForEach(comments) { item in
                commentRow(item, depth: 0)
            }

            if comments.isEmpty && !isLoading {
                Text("No comments yet")
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)
            }

            if let nextCursor {
                Button {
                    Task { await loadMoreComments(cursor: nextCursor) }
                } label: {
                    HStack {
                        if isLoadingMoreComments {
                            ProgressView().tint(colors.accentBrand)
                        }
                        Text(isLoadingMoreComments ? "Loading..." : "Load more comments")
                            .font(PirateTokens.Typography.bodyStrong)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(colors.accentBrand)
                    .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.lg))
                }
                .buttonStyle(.plain)
                .disabled(isLoadingMoreComments)
            }
        }
    }

    private var commentComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $newComment)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90)
                .padding(8)
                .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
                .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderDefault, lineWidth: 1))

            Button {
                Task { await submitComment() }
            } label: {
                HStack {
                    if isSubmittingComment { ProgressView().tint(colors.textOnAccent) }
                    Text(isSubmittingComment ? "Posting..." : "Comment")
                }
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(colors.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
            }
            .buttonStyle(.plain)
            .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingComment)
            .opacity(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmittingComment ? 0.55 : 1)
        }
    }

    private func commentRow(_ item: CommentListItem, depth: Int) -> AnyView {
        let commentId = item.comment.id
        let replies = repliesByCommentId[commentId] ?? []
        let directReplyCount = item.comment.directReplyCount ?? 0
        let isExpanded = expandedReplyIds.contains(commentId)
        let isLoadingReplies = loadingReplyIds.contains(commentId)
        let isReplying = replyingToCommentId == commentId

        return AnyView(VStack(alignment: .leading, spacing: 6) {
            if let displayName = item.comment.authorDisplayName {
                HStack(spacing: 6) {
                    AvatarView(
                        avatarRef: item.comment.authorAvatarRef,
                        size: 20,
                        fallbackLabel: displayName,
                        fallbackSeed: item.comment.authorUserId ?? displayName
                    )
                    Text(displayName)
                        .font(PirateTokens.Typography.smallStrong)
                        .foregroundStyle(colors.textSecondary)
                }
            }

            if let body = item.comment.body {
                Text(body)
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textPrimary)
            }

            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    VoteButton(voteValue: item.viewerVote, onVote: { value in
                        Task { await voteOnComment(commentId: commentId, value: value) }
                    }, isUpvote: true)
                    Text("\(commentScore(item.comment))")
                        .font(PirateTokens.Typography.small)
                        .foregroundStyle(colors.textSecondary)
                    VoteButton(voteValue: item.viewerVote, onVote: { value in
                        Task { await voteOnComment(commentId: commentId, value: value) }
                    }, isUpvote: false)
                }
                .opacity(votingCommentIds.contains(commentId) ? 0.55 : 1)

                Button {
                    if !sessionManager.isAuthenticated {
                        showSignIn = true
                        return
                    }
                    replyingToCommentId = isReplying ? nil : commentId
                    expandedReplyIds.insert(commentId)
                    if replies.isEmpty && directReplyCount > 0 {
                        Task { await loadReplies(commentId: commentId) }
                    }
                } label: {
                    Text("Reply")
                        .font(PirateTokens.Typography.small)
                        .foregroundStyle(colors.accentBrand)
                }
                .buttonStyle(.plain)

                if directReplyCount > 0 || !replies.isEmpty {
                    Button {
                        if isExpanded {
                            expandedReplyIds.remove(commentId)
                        } else {
                            expandedReplyIds.insert(commentId)
                            if replies.isEmpty {
                                Task { await loadReplies(commentId: commentId) }
                            }
                        }
                    } label: {
                        let loadedCount = replies.count
                        let label = isLoadingReplies
                            ? "Loading replies"
                            : isExpanded
                                ? "Hide replies"
                                : "\(max(directReplyCount, loadedCount)) replies"
                        Text(label)
                            .font(PirateTokens.Typography.small)
                            .foregroundStyle(colors.accentBrand)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoadingReplies)
                }
            }

            if isReplying {
                replyComposer(parentCommentId: commentId)
            }

            if isExpanded {
                if isLoadingReplies && replies.isEmpty {
                    ProgressView()
                        .tint(colors.accentBrand)
                        .padding(.vertical, 8)
                }

                ForEach(replies) { reply in
                    commentRow(reply, depth: min(depth + 1, 4))
                }

                if let cursor = nextReplyCursorByCommentId[commentId] {
                    Button {
                        Task { await loadMoreReplies(commentId: commentId, cursor: cursor) }
                    } label: {
                        Text(loadingReplyIds.contains(commentId) ? "Loading..." : "Load more replies")
                            .font(PirateTokens.Typography.smallStrong)
                            .foregroundStyle(colors.accentBrand)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(loadingReplyIds.contains(commentId))
                }
            }
        }
        .padding(.leading, CGFloat(depth) * 18)
        .padding(.vertical, 8))
    }

    private func replyComposer(parentCommentId: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: Binding(
                get: { replyDrafts[parentCommentId] ?? "" },
                set: { replyDrafts[parentCommentId] = $0 }
            ))
            .font(PirateTokens.Typography.body)
            .foregroundStyle(colors.textPrimary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 72)
            .padding(8)
            .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
            .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderDefault, lineWidth: 1))

            HStack {
                Button("Cancel") {
                    replyingToCommentId = nil
                }
                .font(PirateTokens.Typography.smallStrong)
                .foregroundStyle(colors.textSecondary)

                Spacer()

                Button {
                    Task { await submitReply(parentCommentId: parentCommentId) }
                } label: {
                    if submittingReplyIds.contains(parentCommentId) {
                        ProgressView().tint(colors.textOnAccent)
                    } else {
                        Text("Reply")
                    }
                }
                .font(PirateTokens.Typography.smallStrong)
                .foregroundStyle(colors.textOnAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                .disabled((replyDrafts[parentCommentId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submittingReplyIds.contains(parentCommentId))
                .opacity((replyDrafts[parentCommentId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || submittingReplyIds.contains(parentCommentId) ? 0.55 : 1)
            }
        }
        .padding(.vertical, 6)
    }

    private func loadPost() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await loadPostForCurrentSession()
            let localizedPost = loaded.post
            readMode = loaded.readMode
            post = localizedPost
            liveRoomAccess = nil
            liveRoomAccessError = nil
            communityPreview = nil
            comments = []
            nextCursor = nil
            if let communityId = localizedPost.post.communityId {
                communityPreview = await loadCommunityPreview(communityId: communityId, readMode: loaded.readMode)
                let commentsResponse = try await loadComments(
                    communityId: communityId,
                    sort: commentSort,
                    limit: 25,
                    readMode: loaded.readMode
                )
                comments = commentsResponse.items
                nextCursor = commentsResponse.nextCursor
            }
            if localizedPost.post.anchorLiveRoom != nil {
                await loadLiveRoomAccess(for: localizedPost.post)
            }
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadPostForCurrentSession() async throws -> (post: LocalizedPostResponse, readMode: PostReadMode) {
        if sessionManager.isAuthenticated {
            do {
                return (try await ApiClient.shared.authenticatedPost(id: postId), .authenticated)
            } catch let error as ApiError where error.isAuthError || error.isNotFound {
                return (try await ApiClient.shared.publicPost(id: postId), .publicRead)
            }
        }

        return (try await ApiClient.shared.publicPost(id: postId), .publicRead)
    }

    private func loadCommunityPreview(communityId: String, readMode requestedReadMode: PostReadMode) async -> CommunityPreview? {
        if sessionManager.isAuthenticated && requestedReadMode == .authenticated {
            do {
                return try await ApiClient.shared.community(id: communityId)
            } catch let error as ApiError where error.isAuthError || error.isNotFound {
                return try? await ApiClient.shared.publicCommunity(id: communityId)
            } catch {
                return nil
            }
        }

        return try? await ApiClient.shared.publicCommunity(id: communityId)
    }

    private func loadComments(
        communityId: String,
        cursor: String? = nil,
        sort: String,
        limit: Int,
        readMode requestedReadMode: PostReadMode? = nil
    ) async throws -> CommentListResponse {
        let mode = requestedReadMode ?? readMode
        if sessionManager.isAuthenticated && mode == .authenticated {
            return try await ApiClient.shared.comments(
                communityId: communityId,
                postId: postId,
                cursor: cursor,
                sort: sort,
                limit: limit
            )
        }

        return try await ApiClient.shared.publicComments(
            postId: postId,
            cursor: cursor,
            sort: sort,
            limit: limit
        )
    }

    private func loadCommentReplies(
        commentId: String,
        cursor: String? = nil,
        sort: String,
        limit: Int
    ) async throws -> CommentListResponse {
        if usesAuthenticatedRead {
            return try await ApiClient.shared.commentReplies(
                commentId: commentId,
                cursor: cursor,
                sort: sort,
                limit: limit
            )
        }

        return try await ApiClient.shared.publicCommentReplies(
            commentId: commentId,
            cursor: cursor,
            sort: sort,
            limit: limit
        )
    }

    private func loadLiveRoomAccess(for post: Post) async {
        guard
            let communityId = post.communityId,
            let liveRoomId = post.anchorLiveRoom,
            !isLoadingLiveRoomAccess
        else { return }
        isLoadingLiveRoomAccess = true
        liveRoomAccessError = nil
        do {
            liveRoomAccess = try await fetchLiveRoomAccess(communityId: communityId, liveRoomId: liveRoomId)
        } catch let error as ApiError {
            liveRoomAccessError = error.displayMessage
        } catch {
            liveRoomAccessError = error.localizedDescription
        }
        isLoadingLiveRoomAccess = false
    }

    private func fetchLiveRoomAccess(communityId: String, liveRoomId: String) async throws -> LiveRoomAccessResponse {
        if usesAuthenticatedRead {
            do {
                return try await ApiClient.shared.getLiveRoomAccess(communityId: communityId, liveRoomId: liveRoomId)
            } catch let error as ApiError where error.isAuthError || error.isNotFound {
                return try await ApiClient.shared.publicLiveRoomAccess(communityId: communityId, liveRoomId: liveRoomId)
            }
        }
        return try await ApiClient.shared.publicLiveRoomAccess(communityId: communityId, liveRoomId: liveRoomId)
    }

    private func attachLiveRoomViewer(for post: Post) async {
        guard
            let communityId = post.communityId,
            let liveRoomId = post.anchorLiveRoom,
            !isAttachingLiveRoom
        else { return }
        isAttachingLiveRoom = true
        liveRoomAccessError = nil
        do {
            let currentAccess: LiveRoomAccessResponse
            if let liveRoomAccess {
                currentAccess = liveRoomAccess
            } else {
                currentAccess = try await fetchLiveRoomAccess(communityId: communityId, liveRoomId: liveRoomId)
            }
            liveRoomAccess = currentAccess
            guard currentAccess.access.allowed else {
                liveRoomAccessError = liveRoomUnavailableMessage(currentAccess.access.decisionReason)
                isAttachingLiveRoom = false
                return
            }
            let attach: LiveRoomViewerAttachResponse
            if usesAuthenticatedRead {
                attach = try await ApiClient.shared.viewerAttachLiveRoom(communityId: communityId, liveRoomId: liveRoomId)
            } else {
                attach = try await ApiClient.shared.publicViewerAttachLiveRoom(communityId: communityId, liveRoomId: liveRoomId)
            }
            liveRoomAccess = LiveRoomAccessResponse(room: attach.room, access: attach.access)
            liveViewerSession = attach
        } catch let error as ApiError {
            liveRoomAccessError = error.displayMessage
        } catch {
            liveRoomAccessError = error.localizedDescription
        }
        isAttachingLiveRoom = false
    }

    private func renewLiveRoomViewer(uid: UInt) async throws -> LiveRoomViewerAttachResponse {
        guard
            liveViewerSession != nil,
            let communityId = post?.post.communityId,
            let liveRoomId = post?.post.anchorLiveRoom
        else {
            throw ApiError.unknown("Live room session is not active")
        }
        let renewed: LiveRoomViewerAttachResponse
        if usesAuthenticatedRead {
            renewed = try await ApiClient.shared.viewerRenewLiveRoom(communityId: communityId, liveRoomId: liveRoomId, uid: uid)
        } else {
            renewed = try await ApiClient.shared.publicViewerRenewLiveRoom(communityId: communityId, liveRoomId: liveRoomId, uid: uid)
        }
        liveRoomAccess = LiveRoomAccessResponse(room: renewed.room, access: renewed.access)
        liveViewerSession = renewed
        return renewed
    }

    private func liveRoomUnavailableMessage(_ reason: String?) -> String {
        switch reason {
        case "purchase_required":
            return "A ticket is required to watch this live room."
        case "membership_required":
            return "Join this community before watching."
        case "not_live":
            return "The host is not live yet."
        case "ended":
            return "This live room has ended."
        case "canceled":
            return "This live room was canceled."
        default:
            return "This live room is not available right now."
        }
    }

    private func pollLiveRoomAccess() async {
        while !Task.isCancelled {
            guard let post = post?.post, post.anchorLiveRoom != nil else { return }
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            if Task.isCancelled { return }
            await loadLiveRoomAccess(for: post)
            let currentStatus = liveRoomAccess?.room.status ?? post.anchorLiveRoomStatus
            if liveViewerSession != nil && (currentStatus == "ended" || currentStatus == "canceled") {
                liveViewerSession = nil
            }
        }
    }

    private func loadMoreComments(cursor: String) async {
        guard !isLoadingMoreComments, let communityId = post?.post.communityId else { return }
        isLoadingMoreComments = true
        actionError = nil
        do {
            let response = try await loadComments(communityId: communityId, cursor: cursor, sort: commentSort, limit: 25)
            let existingIds = Set(comments.map { $0.id })
            comments.append(contentsOf: response.items.filter { !existingIds.contains($0.id) })
            nextCursor = response.nextCursor
        } catch let error as ApiError {
            actionError = error.displayMessage
        } catch {
            actionError = error.localizedDescription
        }
        isLoadingMoreComments = false
    }

    private func voteOnPost(_ value: Int) async {
        guard sessionManager.isAuthenticated else {
            showSignIn = true
            return
        }
        guard !isVotingPost else { return }
        isVotingPost = true
        do {
            _ = try await ApiClient.shared.votePost(id: postId, value: value)
            await loadPost()
        } catch let error as ApiError {
            actionError = error.displayMessage
        } catch {
            actionError = error.localizedDescription
        }
        isVotingPost = false
    }

    private func voteOnComment(commentId: String, value: Int) async {
        guard sessionManager.isAuthenticated else {
            showSignIn = true
            return
        }
        guard !votingCommentIds.contains(commentId) else { return }
        votingCommentIds.insert(commentId)
        actionError = nil
        do {
            _ = try await ApiClient.shared.voteComment(id: commentId, value: value)
            await refreshCommentsKeepingReplies()
        } catch let error as ApiError {
            actionError = error.displayMessage
        } catch {
            actionError = error.localizedDescription
        }
        votingCommentIds.remove(commentId)
    }

    private func submitComment() async {
        guard sessionManager.isAuthenticated else {
            showSignIn = true
            return
        }
        guard let communityId = post?.post.communityId else { return }
        let text = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSubmittingComment = true
        actionError = nil
        do {
            try await ApiClient.shared.createComment(
                communityId: communityId,
                postId: postId,
                body: CreateCommentRequest(body: text, identityMode: "public")
            )
            newComment = ""
            await loadPost()
        } catch let error as ApiError {
            actionError = error.displayMessage
        } catch {
            actionError = error.localizedDescription
        }
        isSubmittingComment = false
    }

    private func loadReplies(commentId: String) async {
        guard !loadingReplyIds.contains(commentId) else { return }
        loadingReplyIds.insert(commentId)
        actionError = nil
        do {
            let response = try await loadCommentReplies(commentId: commentId, sort: commentSort, limit: 10)
            repliesByCommentId[commentId] = response.items
            if let cursor = response.nextCursor {
                nextReplyCursorByCommentId[commentId] = cursor
            } else {
                nextReplyCursorByCommentId.removeValue(forKey: commentId)
            }
        } catch let error as ApiError {
            actionError = error.displayMessage
        } catch {
            actionError = error.localizedDescription
        }
        loadingReplyIds.remove(commentId)
    }

    private func loadMoreReplies(commentId: String, cursor: String) async {
        guard !loadingReplyIds.contains(commentId) else { return }
        loadingReplyIds.insert(commentId)
        actionError = nil
        do {
            let response = try await loadCommentReplies(commentId: commentId, cursor: cursor, sort: commentSort, limit: 10)
            let existingIds = Set((repliesByCommentId[commentId] ?? []).map { $0.id })
            repliesByCommentId[commentId, default: []].append(contentsOf: response.items.filter { !existingIds.contains($0.id) })
            if let cursor = response.nextCursor {
                nextReplyCursorByCommentId[commentId] = cursor
            } else {
                nextReplyCursorByCommentId.removeValue(forKey: commentId)
            }
        } catch let error as ApiError {
            actionError = error.displayMessage
        } catch {
            actionError = error.localizedDescription
        }
        loadingReplyIds.remove(commentId)
    }

    private func submitReply(parentCommentId: String) async {
        guard sessionManager.isAuthenticated else {
            showSignIn = true
            return
        }
        let text = (replyDrafts[parentCommentId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !submittingReplyIds.contains(parentCommentId) else { return }
        submittingReplyIds.insert(parentCommentId)
        actionError = nil
        do {
            try await ApiClient.shared.createReply(
                commentId: parentCommentId,
                body: CreateCommentRequest(body: text, identityMode: "public")
            )
            replyDrafts[parentCommentId] = ""
            replyingToCommentId = nil
            expandedReplyIds.insert(parentCommentId)
            await loadReplies(commentId: parentCommentId)
            await refreshCommentsKeepingReplies()
        } catch let error as ApiError {
            actionError = error.displayMessage
        } catch {
            actionError = error.localizedDescription
        }
        submittingReplyIds.remove(parentCommentId)
    }

    private func refreshCommentsKeepingReplies() async {
        guard let communityId = post?.post.communityId else { return }
        do {
            let response = try await loadComments(
                communityId: communityId,
                sort: commentSort,
                limit: max(25, comments.count)
            )
            comments = response.items
            nextCursor = response.nextCursor
        } catch {
            await loadPost()
        }
    }

    private func changeCommentSort(_ sort: String) {
        guard sort != commentSort else { return }
        commentSort = sort
        repliesByCommentId = [:]
        nextReplyCursorByCommentId = [:]
        expandedReplyIds = []
        Task { await loadPost() }
    }

    private func commentScore(_ comment: Comment) -> Int {
        if let score = comment.score { return score }
        return (comment.upvoteCount ?? 0) - (comment.downvoteCount ?? 0)
    }

    private func postScore(_ post: LocalizedPostResponse) -> Int {
        let upvotes = post.upvoteCount ?? post.post.upvoteCount ?? 0
        let downvotes = post.downvoteCount ?? post.post.downvoteCount ?? 0
        return upvotes - downvotes
    }

    private func authorLabel(for post: Post) -> String {
        post.authorAnonymousLabel
            ?? post.authorDisplayName
            ?? post.authorUserId.map { "\($0.prefix(16)).pirate" }
            ?? "anonymous"
    }

    private func authorProfileRoute(for post: Post) -> PirateRoute? {
        guard post.authorAnonymousLabel == nil else { return nil }
        guard let userId = post.authorUserId?.trimmingCharacters(in: .whitespacesAndNewlines), !userId.isEmpty else {
            return nil
        }
        return .user(userId)
    }

    private func relativeTime(from timestamp: String) -> String {
        let date: Date?
        if let epoch = Double(timestamp) {
            date = Date(timeIntervalSince1970: epoch)
        } else {
            date = ISO8601DateFormatter().date(from: timestamp)
        }
        guard let date else { return "" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 2592000 { return "\(Int(interval / 86400))d" }
        return "\(Int(interval / 2592000))mo"
    }
}
