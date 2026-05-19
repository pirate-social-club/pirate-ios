import SwiftUI

@MainActor
final class PostSnapshotCache {
    static let shared = PostSnapshotCache()

    private var postsById: [String: LocalizedPostResponse] = [:]
    private var insertionOrder: [String] = []
    private let limit = 150

    private init() {}

    func post(id: String) -> LocalizedPostResponse? {
        postsById[id]
    }

    func store(_ post: LocalizedPostResponse) {
        let id = post.id
        if postsById[id] == nil {
            insertionOrder.append(id)
        }
        postsById[id] = post
        trimIfNeeded()
    }

    func store(contentsOf posts: [LocalizedPostResponse]) {
        posts.forEach(store)
    }

    private func trimIfNeeded() {
        while insertionOrder.count > limit {
            let id = insertionOrder.removeFirst()
            postsById[id] = nil
        }
    }
}

private enum PostReadMode {
    case authenticated
    case publicRead
}

private enum CommentComposerTarget: Identifiable {
    case root
    case reply(CommentListItem)

    var id: String {
        switch self {
        case .root:
            return "root"
        case .reply(let item):
            return "reply:\(item.comment.id)"
        }
    }

    var title: String {
        switch self {
        case .root:
            return "Add comment"
        case .reply:
            return "Add reply"
        }
    }
}

private struct CommentComposeView: View {
    @Environment(\.pirateColors) private var colors
    let target: CommentComposerTarget
    @Binding var text: String
    let isSubmitting: Bool
    let onCancel: () -> Void
    let onPost: () -> Void
    @FocusState private var isEditorFocused: Bool

    private var canPost: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(colors.borderSoft)
            replyContext
            editor
        }
        .background(colors.bgPage)
        .safeAreaInset(edge: .bottom) {
            attachmentToolbar
                .padding(.horizontal, PirateTokens.pageGutter)
                .padding(.vertical, 8)
                .background(colors.bgPage)
        }
        .task {
            isEditorFocused = true
        }
    }

    private var header: some View {
        HStack {
            Button {
                onCancel()
            } label: {
                PirateIconView(icon: .x, size: 22, color: colors.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Text(target.title)
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(colors.textPrimary)

            Spacer()

            Button {
                onPost()
            } label: {
                if isSubmitting {
                    ProgressView().tint(colors.accentBrand)
                        .frame(width: 52, height: 44)
                } else {
                    Text("Post")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(canPost ? colors.accentBrand : colors.textDisabled)
                        .frame(minWidth: 52, minHeight: 44, alignment: .trailing)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canPost)
        }
        .padding(.leading, 4)
        .padding(.trailing, PirateTokens.pageGutter)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var replyContext: some View {
        if case .reply(let item) = target {
            HStack(alignment: .top, spacing: 10) {
                AvatarView(
                    avatarRef: item.comment.authorAvatarRef,
                    size: 28,
                    fallbackLabel: commentAuthorLabel(item.comment),
                    fallbackSeed: item.comment.authorUserId ?? commentAuthorLabel(item.comment)
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("Replying to \(commentAuthorLabel(item.comment))")
                        .font(PirateTokens.Typography.smallStrong)
                        .foregroundStyle(colors.textPrimary)
                    if let body = (item.translatedBody ?? item.comment.body)?.trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
                        Text(body)
                            .font(PirateTokens.Typography.small)
                            .foregroundStyle(colors.textSecondary)
                            .lineLimit(3)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, PirateTokens.pageGutter)
            .padding(.vertical, 12)
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("What are your thoughts?")
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textSecondary)
                    .padding(.top, 10)
                    .padding(.horizontal, 5)
            }

            TextEditor(text: $text)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)
                .scrollContentBackground(.hidden)
                .focused($isEditorFocused)
                .padding(.horizontal, -5)
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var attachmentToolbar: some View {
        HStack(spacing: 4) {
            composerIconButton(icon: .linkSimple, label: "Add link")
            composerIconButton(icon: .imageSquare, label: "Add image")
            Spacer()
        }
    }

    private func composerIconButton(icon: PhosphorComposerIcon, label: String) -> some View {
        Button {
        } label: {
            PhosphorComposerIconView(icon: icon, size: 23, color: colors.textSecondary)
                .frame(width: 44, height: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func commentAuthorLabel(_ comment: Comment) -> String {
        comment.authorAnonymousLabel
            ?? comment.authorDisplayName
            ?? comment.authorUserId.map { "\($0.prefix(16)).pirate" }
            ?? "anonymous"
    }
}

private enum PhosphorComposerIcon {
    case linkSimple
    case imageSquare
}

private struct PhosphorComposerIconView: View {
    let icon: PhosphorComposerIcon
    let size: CGFloat
    let color: Color

    var body: some View {
        PhosphorComposerIconShape(icon: icon)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            .frame(width: size, height: size)
    }
}

private struct PhosphorComposerIconShape: Shape {
    let icon: PhosphorComposerIcon

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scaleX = rect.width / 24
        let scaleY = rect.height / 24

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }

        func iconRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(
                x: rect.minX + x * scaleX,
                y: rect.minY + y * scaleY,
                width: width * scaleX,
                height: height * scaleY
            )
        }

        switch icon {
        case .linkSimple:
            path.move(to: point(8.5, 12))
            path.addLine(to: point(15.5, 12))
            path.move(to: point(9.5, 7.2))
            path.addLine(to: point(7.1, 7.2))
            path.addCurve(to: point(2.8, 11.5), control1: point(4.7, 7.2), control2: point(2.8, 9.1))
            path.addCurve(to: point(7.1, 15.8), control1: point(2.8, 13.9), control2: point(4.7, 15.8))
            path.addLine(to: point(9.5, 15.8))
            path.move(to: point(14.5, 7.2))
            path.addLine(to: point(16.9, 7.2))
            path.addCurve(to: point(21.2, 11.5), control1: point(19.3, 7.2), control2: point(21.2, 9.1))
            path.addCurve(to: point(16.9, 15.8), control1: point(21.2, 13.9), control2: point(19.3, 15.8))
            path.addLine(to: point(14.5, 15.8))

        case .imageSquare:
            path.addRoundedRect(in: iconRect(3.5, 4.5, 17, 15), cornerSize: CGSize(width: 2.4 * scaleX, height: 2.4 * scaleY))
            path.addEllipse(in: iconRect(7, 7.4, 2.5, 2.5))
            path.move(to: point(5.8, 17.1))
            path.addLine(to: point(10.1, 12.8))
            path.addCurve(to: point(12.3, 12.8), control1: point(10.7, 12.2), control2: point(11.7, 12.2))
            path.addLine(to: point(14.2, 14.7))
            path.addLine(to: point(15.1, 13.8))
            path.addCurve(to: point(17.3, 13.8), control1: point(15.7, 13.2), control2: point(16.7, 13.2))
            path.addLine(to: point(20.1, 16.6))
        }

        return path
    }
}

struct PostView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    @Environment(\.dismiss) private var dismiss
    var sessionManager: SessionManager

    let postId: String

    @State private var post: LocalizedPostResponse?
    @State private var communityPreview: CommunityPreview?
    @State private var authorProfile: Profile?
    @State private var comments: [CommentListItem] = []
    @State private var nextCursor: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSignIn = false
    @State private var newComment = ""
    @State private var actionError: String?
    @State private var commentSort = "best"
    @State private var isLoadingMoreComments = false
    @State private var replyDrafts: [String: String] = [:]
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
    @State private var songListingsByAssetId: [String: CommunityListing] = [:]
    @State private var songPurchasesByAssetId: [String: CommunityPurchase] = [:]
    @State private var isLoadingSongCommerce = false
    @State private var songCommerceError: String?
    @State private var songPurchaseMessage: String?
    @State private var readMode: PostReadMode = .publicRead
    @State private var isVotingPost = false
    @State private var activeCommentComposer: CommentComposerTarget?
    @State private var composeText = ""
    @State private var isSubmittingCompose = false
    @State private var gateController = CommunityInteractionGateController()
    @State private var selfVerificationRequest: SelfVerificationSheetRequest?

    init(sessionManager: SessionManager, postId: String, initialPost: LocalizedPostResponse? = nil) {
        self.sessionManager = sessionManager
        self.postId = postId
        let seededPost = initialPost ?? PostSnapshotCache.shared.post(id: postId)
        self._post = State(initialValue: seededPost)
        self._comments = State(initialValue: seededPost?.threadSnapshot ?? [])
        self._isLoading = State(initialValue: seededPost == nil)
    }

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
                    ErrorView(message: error, retry: { await loadPost() })
                }
            }
            .padding(.horizontal, PirateTokens.pageGutter)
            .padding(.bottom, post == nil ? 0 : 24)
        }
        .background(colors.bgPage)
        .safeAreaInset(edge: .bottom) {
            if post != nil {
                bottomCommentAccessory
                    .padding(.horizontal, PirateTokens.pageGutter)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .background(colors.bgPage)
            }
        }
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
                    PirateSystemIconView(systemName: "slider.horizontal.3", size: 22)
                        .foregroundStyle(colors.textSecondary)
                        .frame(width: 34, height: 34)
                }
            }
        }
        .task {
            await loadPost(blocking: post == nil)
        }
        .task(id: post?.post.anchorLiveRoom) {
            await pollLiveRoomAccess()
        }
        .sheet(isPresented: $showSignIn) {
            SignInDrawer(sessionManager: sessionManager, isPresented: $showSignIn)
        }
        .sheet(isPresented: Binding(
            get: { gateController.isSheetPresented },
            set: { isPresented in
                if !isPresented { gateController.closeSheet() }
            }
        )) {
            CommunityInteractionGateSheet(
                controller: gateController,
                onSelfVerificationRequested: { request in
                    selfVerificationRequest = request
                }
            )
        }
        .sheet(item: $selfVerificationRequest) { request in
            SelfVerificationDrawer(
                sessionManager: sessionManager,
                intent: request.intent,
                requestedCapabilities: request.requestedCapabilities,
                verificationRequirements: request.verificationRequirements,
                isPresented: Binding(
                    get: { selfVerificationRequest != nil },
                    set: { if !$0 { selfVerificationRequest = nil } }
                )
            )
        }
        .onAppear {
            Task { await gateController.resumeWithRetry() }
        }
        .fullScreenCover(item: $activeCommentComposer, onDismiss: {
            persistComposeDraft()
        }) { target in
            CommentComposeView(
                target: target,
                text: $composeText,
                isSubmitting: isSubmittingCompose,
                onCancel: {
                    persistComposeDraft()
                    activeCommentComposer = nil
                },
                onPost: {
                    Task { await submitCompose(target: target) }
                }
            )
            .pirateTheme()
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
            postAuthorHeader(localizedPost)

            if localizedPost.post.anchorLiveRoom != nil {
                LiveRoomPostContentView(
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
                        actionError = "Ticket checkout is not available in the iOS app yet."
                    },
                    onSignIn: {
                        showSignIn = true
                    }
                )
            } else {
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

                let isSongPost = localizedPost.post.postType == "song"
                let mediaItem = PiratePostMediaItem.primary(for: localizedPost.post)
                if isSongPost {
                    SongPostView(
                        localizedPost: localizedPost,
                        context: .detail,
                        commerce: songCommerce(for: localizedPost.post),
                        isLoadingCommerce: isLoadingSongCommerce,
                        commerceError: songCommerceError,
                        purchaseMessage: songPurchaseMessage,
                        onBuy: {
                            handleSongBuy(localizedPost)
                        },
                        onSignIn: {
                            showSignIn = true
                        }
                    )
                } else if mediaItem != nil {
                    PostMediaView(post: localizedPost.post, context: .detail)
                }

                if localizedPost.post.linkUrl != nil {
                    PostLinkPreview(post: localizedPost.post, compact: false, showsPreviewImage: mediaItem == nil && !isSongPost)
                }
            }

            postEngagementBar(localizedPost)
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func postAuthorHeader(_ localizedPost: LocalizedPostResponse) -> some View {
        postAuthorHeaderContent(localizedPost)
    }

    private func postAuthorHeaderContent(_ localizedPost: LocalizedPostResponse) -> some View {
        let post = localizedPost.post
        let communityLabel = postCommunityLabel(for: post)
        let communityIsUnverified = postCommunityIsUnverified(for: post)
        let author = authorLabel(for: post)
        let time = formatRelativeTimestamp(post.createdAt)

        return HStack(spacing: 10) {
            if let route = communityRoute(for: post) {
                NavigationLink(value: route) {
                    AvatarView(
                        avatarRef: communityPreview?.community.avatarRef,
                        size: 38,
                        fallbackLabel: communityLabel,
                        fallbackSeed: post.communityId ?? communityLabel
                    )
                }
                .buttonStyle(.plain)
            } else {
                AvatarView(
                    avatarRef: communityPreview?.community.avatarRef,
                    size: 38,
                    fallbackLabel: communityLabel,
                    fallbackSeed: post.communityId ?? communityLabel
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                if let route = communityRoute(for: post) {
                    NavigationLink(value: route) {
                        CommunityNameLabel(
                            text: communityLabel,
                            isUnverified: communityIsUnverified,
                            font: PirateTokens.Typography.smallStrong,
                            color: colors.textPrimary,
                            iconSize: 13
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    CommunityNameLabel(
                        text: communityLabel,
                        isUnverified: communityIsUnverified,
                        font: PirateTokens.Typography.smallStrong,
                        color: colors.textPrimary,
                        iconSize: 13
                    )
                }

                HStack(spacing: 5) {
                    if let route = authorProfileRoute(for: post) {
                        NavigationLink(value: route) {
                            Text(author)
                                .font(PirateTokens.Typography.small)
                                .foregroundStyle(colors.textSecondary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(author)
                            .font(PirateTokens.Typography.small)
                            .foregroundStyle(colors.textSecondary)
                            .lineLimit(1)
                    }

                    CommunityRoleIconBadgeView(role: localizedPost.authorCommunityRole, size: 14)

                    Text("· \(time)")
                        .font(PirateTokens.Typography.small)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityLabel("\(communityLabel), \(author), \(time)")
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

    private var bottomCommentAccessory: some View {
        Button {
            openRootComposer()
        } label: {
            HStack(spacing: 10) {
                PirateIconView(icon: .chatCircle, size: 18, color: colors.textSecondary)
                Text(rootComposerPrompt)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a comment")
    }

    private func commentRow(_ item: CommentListItem, depth: Int) -> AnyView {
        let commentId = item.comment.id
        let replies = repliesByCommentId[commentId] ?? []
        let directReplyCount = item.comment.directReplyCount ?? 0
        let isExpanded = expandedReplyIds.contains(commentId)
        let isLoadingReplies = loadingReplyIds.contains(commentId)

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

            HStack(spacing: 10) {
                VotePill(
                    score: commentScore(item.comment),
                    voteValue: item.viewerVote,
                    disabled: votingCommentIds.contains(commentId),
                    isWorking: votingCommentIds.contains(commentId),
                    onVote: { value in
                        Task { await voteOnComment(commentId: commentId, value: value) }
                    }
                )

                ReplyActionPill(isActive: activeCommentComposer?.id == "reply:\(commentId)") {
                    openReplyComposer(for: item, replies: replies, directReplyCount: directReplyCount)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 2)

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

    private func loadPost(blocking: Bool = true) async {
        if blocking {
            isLoading = true
        }
        errorMessage = nil
        do {
            let loaded = try await loadPostForCurrentSession()
            let localizedPost = loaded.post
            readMode = loaded.readMode
            liveRoomAccess = nil
            liveRoomAccessError = nil
            songListingsByAssetId = [:]
            songPurchasesByAssetId = [:]
            songCommerceError = nil
            songPurchaseMessage = nil
            communityPreview = nil
            authorProfile = nil
            comments = localizedPost.threadSnapshot ?? []
            nextCursor = nil
            post = localizedPost
            PostSnapshotCache.shared.store(localizedPost)
            isLoading = false
            authorProfile = await loadAuthorProfile(for: localizedPost.post)
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
            if localizedPost.post.postType == "song" {
                await loadSongCommerce(for: localizedPost.post)
            }
        } catch let error as ApiError {
            if post == nil {
                errorMessage = error.displayMessage
            }
        } catch {
            if post == nil {
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func loadSongCommerce(for post: Post) async {
        guard sessionManager.isAuthenticated, post.accessMode == "locked", let communityId = post.communityId else {
            return
        }

        isLoadingSongCommerce = true
        songCommerceError = nil
        do {
            async let listingsResponse = ApiClient.shared.communityListings(communityId: communityId)
            async let purchasesResponse = ApiClient.shared.communityPurchases(communityId: communityId)
            let (listings, purchases) = try await (listingsResponse, purchasesResponse)
            songListingsByAssetId = Dictionary(listings.items.compactMap { listing in
                guard let asset = listing.asset, !asset.isEmpty else { return nil }
                return (asset, listing)
            }, uniquingKeysWith: { current, next in
                current.status == "active" ? current : next
            })
            songPurchasesByAssetId = Dictionary(purchases.items.compactMap { purchase in
                guard let asset = purchase.asset, !asset.isEmpty else { return nil }
                return (asset, purchase)
            }, uniquingKeysWith: { current, _ in
                current
            })
        } catch let error as ApiError {
            if error.isNotFound || error.isForbidden || error.isAuthError {
                songCommerceError = nil
            } else {
                songCommerceError = error.displayMessage
            }
        } catch {
            songCommerceError = error.localizedDescription
        }
        isLoadingSongCommerce = false
    }

    private func songCommerce(for post: Post) -> SongPostCommerceState {
        guard let asset = post.asset else {
            return SongPostCommerceState(listing: nil, purchase: nil, currentUserId: sessionManager.user?.id)
        }
        return SongPostCommerceState(
            listing: songListingsByAssetId[asset],
            purchase: songPurchasesByAssetId[asset],
            currentUserId: sessionManager.user?.id
        )
    }

    private func handleSongBuy(_ localizedPost: LocalizedPostResponse) {
        guard sessionManager.isAuthenticated else {
            showSignIn = true
            return
        }

        guard let asset = localizedPost.post.asset, songListingsByAssetId[asset] != nil else {
            songPurchaseMessage = "This song is not available for purchase right now."
            return
        }

        songPurchaseMessage = "Song checkout is not available in the iOS app yet."
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

    private func loadAuthorProfile(for post: Post) async -> Profile? {
        guard post.authorAnonymousLabel == nil else { return nil }
        guard post.authorIdentityMode != "anonymous" else { return nil }
        guard let userId = post.authorUserId?.trimmingCharacters(in: .whitespacesAndNewlines), !userId.isEmpty else {
            return nil
        }

        return try? await ApiClient.shared.profile(userId: userId)
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
            if error.isResolvedLiveRoomUnavailable {
                await loadLiveRoomAccess(for: post)
            } else {
                liveRoomAccessError = error.displayMessage
            }
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
        guard let post else { return }
        let targetPostId = post.post.id
        let communityId = post.post.communityId ?? ""
        let communityName = communityPreview?.community.displayName ?? "this community"
        guard !isVotingPost else { return }
        isVotingPost = true
        actionError = nil

        guard !communityId.isEmpty else {
            guard sessionManager.isAuthenticated else {
                showSignIn = true
                isVotingPost = false
                return
            }
            do {
                let altchaPayload = try await gateController.solvePostVotePayload(postId: targetPostId, value: value)
                _ = try await ApiClient.shared.votePost(id: targetPostId, value: value, altchaPayload: altchaPayload)
                await loadPost()
            } catch let error as ApiError {
                actionError = error.displayMessage
            } catch {
                actionError = error.localizedDescription
            }
            isVotingPost = false
            return
        }

        await gateController.runPostVote(
            isAuthenticated: sessionManager.isAuthenticated,
            userId: sessionManager.user?.id,
            communityId: communityId,
            communityName: communityName,
            postId: targetPostId,
            value: value,
            showSignIn: { showSignIn = true },
            perform: { altchaPayload in
                _ = try await ApiClient.shared.votePost(id: targetPostId, value: value, altchaPayload: altchaPayload)
                await loadPost()
            }
        )
        if let inlineError = gateController.inlineError {
            actionError = inlineError
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
            let altchaPayload = try await gateController.solveCommentVotePayload(commentId: commentId, value: value)
            _ = try await ApiClient.shared.voteComment(id: commentId, value: value, altchaPayload: altchaPayload)
            await refreshCommentsKeepingReplies()
        } catch let error as ApiError {
            actionError = error.displayMessage
        } catch {
            actionError = error.localizedDescription
        }
        votingCommentIds.remove(commentId)
    }

    private func submitCompose(target: CommentComposerTarget) async {
        guard sessionManager.isAuthenticated else {
            showSignIn = true
            return
        }
        let text = composeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSubmittingCompose else { return }
        isSubmittingCompose = true
        actionError = nil
        do {
            switch target {
            case .root:
                guard let communityId = post?.post.communityId else {
                    isSubmittingCompose = false
                    return
                }
                try await ApiClient.shared.createComment(
                    communityId: communityId,
                    postId: postId,
                    body: CreateCommentRequest(body: text, identityMode: "public")
                )
                newComment = ""
                composeText = ""
                activeCommentComposer = nil
                await loadPost()
            case .reply(let item):
                let parentCommentId = item.comment.id
                try await ApiClient.shared.createReply(
                    commentId: parentCommentId,
                    body: CreateCommentRequest(body: text, identityMode: "public")
                )
                replyDrafts[parentCommentId] = ""
                composeText = ""
                activeCommentComposer = nil
                expandedReplyIds.insert(parentCommentId)
                await loadReplies(commentId: parentCommentId)
                await refreshCommentsKeepingReplies()
            }
        } catch let error as ApiError {
            actionError = error.displayMessage
        } catch {
            actionError = error.localizedDescription
        }
        isSubmittingCompose = false
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

    private func openRootComposer() {
        guard sessionManager.isAuthenticated else {
            showSignIn = true
            return
        }
        composeText = newComment
        activeCommentComposer = .root
    }

    private func openReplyComposer(for item: CommentListItem, replies: [CommentListItem], directReplyCount: Int) {
        guard sessionManager.isAuthenticated else {
            showSignIn = true
            return
        }
        let commentId = item.comment.id
        composeText = replyDrafts[commentId] ?? ""
        activeCommentComposer = .reply(item)
        expandedReplyIds.insert(commentId)
        if replies.isEmpty && directReplyCount > 0 {
            Task { await loadReplies(commentId: commentId) }
        }
    }

    private func persistComposeDraft() {
        guard let target = activeCommentComposer else { return }
        switch target {
        case .root:
            newComment = composeText
        case .reply(let item):
            replyDrafts[item.comment.id] = composeText
        }
    }

    private var rootComposerPrompt: String {
        let trimmed = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Add a comment" : trimmed
    }

    private func authorLabel(for post: Post) -> String {
        post.authorAnonymousLabel
            ?? profileHandleLabel(authorProfile)
            ?? post.authorDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? post.authorUserId.map { "\($0.prefix(16)).pirate" }
            ?? "anonymous"
    }

    private func authorProfileRoute(for post: Post) -> PirateRoute? {
        guard post.authorAnonymousLabel == nil else { return nil }
        if let handle = profileHandleLabel(authorProfile) {
            return .publicProfile(handle)
        }
        guard let userId = post.authorUserId?.trimmingCharacters(in: .whitespacesAndNewlines), !userId.isEmpty else {
            return nil
        }
        return .user(userId)
    }

    private func postCommunityLabel(for post: Post) -> String {
        if let community = communityPreview?.community {
            return communityPresentationLabel(
                communityId: community.communityId,
                displayName: community.displayName,
                routeSlug: community.routeSlug,
                namespaceVerificationId: community.namespaceVerificationId
            )
        }
        if let communityId = post.communityId {
            return formatCommunityRouteLabel(communityId: communityId)
        }
        return "c/community"
    }

    private func postCommunityIsUnverified(for post: Post) -> Bool {
        guard let community = communityPreview?.community else { return false }
        return !isCommunityRouteVerified(
            routeSlug: community.routeSlug,
            namespaceVerificationId: community.namespaceVerificationId
        )
    }

    private func communityRoute(for post: Post) -> PirateRoute? {
        if let community = communityPreview?.community {
            return .community(community.communityId)
        }
        guard let communityId = post.communityId?.trimmingCharacters(in: .whitespacesAndNewlines), !communityId.isEmpty else {
            return nil
        }
        return .community(communityId)
    }

    private func profileHandleLabel(_ profile: Profile?) -> String? {
        normalizedHandleLabel(profile?.primaryPublicHandle?.label)
            ?? normalizedHandleLabel(profile?.globalHandle?.label)
    }

    private func normalizedHandleLabel(_ value: String?) -> String? {
        guard var label = value?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else {
            return nil
        }
        if label.lowercased().hasPrefix("u/") {
            label = String(label.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !label.isEmpty else { return nil }
        return label.contains(".") ? label : "\(label).pirate"
    }
}
