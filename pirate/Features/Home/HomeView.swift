import SwiftUI

@MainActor
struct HomeView: View {
    private static let feedStaleInterval: TimeInterval = 30
    private static let pullRefreshTriggerDistance: CGFloat = 72
    private static let feedTopAnchor = "homeFeedTop"

    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    var sessionManager: SessionManager
    var scrollToTopTrigger: Int = 0

    @State private var feedItems: [HomeFeedItem] = []
    @State private var nextCursor: String?
    @State private var lastFeedLoadedAt: Date?
    @State private var lastFeedCacheKey: String?
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var isRefreshingFeed = false
    @State private var didTriggerPullRefresh = false
    @State private var errorMessage: String?
    @State private var paginationError: String?
    @State private var actionError: String?
    @State private var sortMode: String = "best"
    @State private var showSignIn = false
    @State private var showSidebar = false
    @State private var votingPostIds: Set<String> = []
    @State private var attachingLiveRoomIds: Set<String> = []
    @State private var liveViewerSessionsById: [String: LiveRoomViewerAttachResponse] = [:]
    @State private var visibleLiveRoomIds: [String] = []
    @State private var activeFeedLiveRoomId: String?
    @State private var gateController = CommunityInteractionGateController()
    @State private var selfVerificationRequest: SelfVerificationSheetRequest?

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    pullRefreshProbe
                        .id(Self.feedTopAnchor)

                    if isRefreshingFeed {
                        feedRefreshIndicator
                    }

                    if isLoading && feedItems.isEmpty {
                        LoadingView()
                            .frame(height: 200)
                    } else if let error = errorMessage, feedItems.isEmpty {
                        ErrorView(message: error, retry: { await loadFeed(force: true) })
                    } else {
                        if let paginationError {
                            paginationBanner(paginationError)
                        }
                        if let actionError {
                            actionBanner(actionError)
                        }

                        if feedItems.isEmpty {
                            EmptyStateView(
                                icon: "doc.text",
                                title: "No posts yet",
                                subtitle: "Posts from communities you follow will appear here."
                            )
                        } else {
                            ForEach(feedItems) { item in
                                feedItemRow(item)
                            }

                            if let nextCursor = nextCursor {
                                loadMoreButton(nextCursor: nextCursor)
                            }
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: "homeFeedScroll")
            .background(colors.bgPage)
            .navigationTitle("Pirate")
            .inlineNavigationBarTitle()
            #if os(iOS)
            .scrollBounceBehavior(.always)
            .toolbarBackground(colors.bgPage, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSidebar = true
                    } label: {
                        PirateIconView(icon: .list, size: 22, color: colors.textPrimary)
                    }
                    .accessibilityLabel("Open navigation")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: PirateRoute.submit) {
                        PirateIconView(icon: .plus, size: 22, color: colors.textPrimary)
                    }
                    .accessibilityLabel("Create post")
                }
            }
            .task {
                await loadFeed()
            }
            .onChange(of: scrollToTopTrigger) { _, _ in
                withAnimation(.easeInOut(duration: 0.35)) {
                    scrollProxy.scrollTo(Self.feedTopAnchor, anchor: .top)
                }
            }
            .onPreferenceChange(HomeFeedPullRefreshOffsetKey.self) { distance in
                handlePullRefreshDistance(distance)
            }
            .sheet(isPresented: $showSignIn) {
                SignInDrawer(sessionManager: sessionManager, isPresented: $showSignIn)
            }
            .sheet(isPresented: $showSidebar) {
                HomeSidebarSheet(
                    isPresented: $showSidebar,
                    sortMode: sortMode,
                    onSelectSort: { sort in
                        showSidebar = false
                        sortMode = sort
                        Task { await loadFeed(force: true) }
                    }
                )
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
        }
    }

    private var pullRefreshProbe: some View {
        Color.clear
            .frame(height: 0)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: HomeFeedPullRefreshOffsetKey.self,
                        value: max(0, proxy.frame(in: .named("homeFeedScroll")).minY)
                    )
                }
            )
    }

    private var feedRefreshIndicator: some View {
        HStack {
            ProgressView()
                .controlSize(.small)
                .tint(colors.accentBrand)
                .frame(width: 18, height: 18)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .transition(.opacity)
        .accessibilityLabel("Refreshing feed")
    }

    @ViewBuilder
    private func paginationBanner(_ message: String) -> some View {
        HStack {
            PirateIconView(icon: .flag, size: 18, color: colors.accentWarning)
            Text(message)
                .font(PirateTokens.Typography.small)
                .foregroundStyle(colors.textSecondary)
            Spacer()
            Button("Retry") {
                paginationError = nil
                if let cursor = nextCursor {
                    Task { await loadMore(cursor: cursor) }
                }
            }
            .font(PirateTokens.Typography.small)
            .foregroundStyle(colors.accentBrand)
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 8)
        .background(colors.surfaceWarning.opacity(0.15))
    }

    @ViewBuilder
    private func actionBanner(_ message: String) -> some View {
        HStack {
            PirateIconView(icon: .flag, size: 18, color: colors.accentWarning)
            Text(message)
                .font(PirateTokens.Typography.small)
                .foregroundStyle(colors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 8)
        .background(colors.surfaceWarning.opacity(0.15))
    }

    private func feedItemRow(_ item: HomeFeedItem) -> some View {
        let post = item.post.post

        return VStack(alignment: .leading, spacing: 10) {
            communityHeader(item)

            NavigationLink(value: PirateRoute.post(post.id)) {
                feedItemPostPreview(item)
            }
            .buttonStyle(.plain)

            if post.anchorLiveRoom != nil {
                liveRoomFeedSurface(for: post)
            }

            feedItemFooter(item)
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 16)
        .background(colors.bgPage)
        .overlay(Rectangle().fill(colors.borderSoft).frame(height: 0.5), alignment: .bottom)
        .onAppear {
            liveRoomDidAppear(post)
        }
        .onDisappear {
            liveRoomDidDisappear(post)
        }
        .task(id: liveRoomAutoplayTaskKey(for: post)) {
            guard liveRoomIsLive(post) else { return }
            await prepareAutoplayLiveRoom(for: post)
        }
    }

    private func feedItemPostPreview(_ item: HomeFeedItem) -> some View {
        let isPlayingLiveRoom = liveRoomIsPlaying(item.post.post)

        return VStack(alignment: .leading, spacing: 10) {
            if !isPlayingLiveRoom, let title = item.post.post.title {
                Text(title)
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(4)
            }

            if !isPlayingLiveRoom, let body = item.post.post.body, !body.isEmpty, body != item.post.post.title {
                Text(body)
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(5)
            }

            let isSongPost = item.post.post.postType == "song"
            let mediaItem = PiratePostMediaItem.primary(for: item.post.post)
            if !isPlayingLiveRoom && isSongPost {
                SongPostView(
                    localizedPost: item.post,
                    context: .feed,
                    commerce: SongPostCommerceState(
                        listing: nil,
                        purchase: nil,
                        currentUserId: sessionManager.user?.id
                    ),
                    onSignIn: {
                        showSignIn = true
                    }
                )
            } else if !isPlayingLiveRoom && mediaItem != nil {
                PostMediaView(post: item.post.post, context: .feed)
            }

            let showsLinkPreviewImage = mediaItem == nil && !isSongPost
            if !isPlayingLiveRoom && PostLinkPreview.canRender(post: item.post.post, showsPreviewImage: showsLinkPreviewImage) {
                PostLinkPreview(post: item.post.post, compact: true, showsPreviewImage: showsLinkPreviewImage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func liveRoomFeedSurface(for post: Post) -> some View {
        if
            let liveRoomId = post.anchorLiveRoom,
            activeFeedLiveRoomId == liveRoomId,
            let liveViewerSession = liveViewerSessionsById[liveRoomId]
        {
            LiveRoomInlineViewerView(
                attachResponse: liveViewerSession,
                onRenew: { uid in
                    try await renewHomeLiveRoomViewer(liveRoomId: liveRoomId, uid: uid)
                }
            )
        }
    }

    private func communityHeader(_ item: HomeFeedItem) -> some View {
        let community = item.community
        let label = communityPresentationLabel(
            communityId: community.id,
            displayName: community.displayName,
            routeSlug: community.routeSlug,
            routeSlugImpliesVerified: true
        )
        let isUnverified = !isCommunityRouteVerified(routeSlug: community.routeSlug, routeSlugImpliesVerified: true)

        return HStack(spacing: 8) {
            AvatarView(avatarRef: community.avatarRef, size: 20, fallbackLabel: community.displayName)
            NavigationLink(value: PirateRoute.community(community.id)) {
                CommunityNameLabel(
                    text: label,
                    isUnverified: isUnverified,
                    font: PirateTokens.Typography.smallStrong,
                    color: colors.textSecondary,
                    iconSize: 13
                )
            }
            .buttonStyle(.plain)

            if let createdAt = itemCreatedAt(item) {
                Text("· \(createdAt)")
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.textSecondary)
            }

            Spacer()

            if let following = community.viewerFollowing {
                Button {
                    if !sessionManager.isAuthenticated {
                        showSignIn = true
                        return
                    }
                    Task { await toggleFollow(community) }
                } label: {
                    Text(following ? "Following" : "Follow")
                        .font(PirateTokens.Typography.smallStrong)
                        .foregroundStyle(following ? colors.accentBrand : colors.textOnAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(following ? colors.surfaceSubtle : colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func feedItemFooter(_ item: HomeFeedItem) -> some View {
        let post = item.post
        return HStack(spacing: 10) {
            VotePill(
                score: postScore(post),
                voteValue: post.viewerVote,
                disabled: votingPostIds.contains(post.post.id),
                onVote: { value in
                    Task { await voteOnPost(item: item, value: value) }
                }
            )

            CommentCountPill(count: post.commentCount ?? post.post.commentCount ?? 0)

            Spacer()
        }
        .padding(.top, 2)
    }

    private func loadMoreButton(nextCursor: String) -> some View {
        Button {
            Task { await loadMore(cursor: nextCursor) }
        } label: {
            HStack {
                if isLoadingMore {
                    ProgressView()
                        .tint(colors.accentBrand)
                }
                Text(isLoadingMore ? "Loading..." : "Load more")
                    .font(PirateTokens.Typography.bodyStrong)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(colors.accentBrand)
            .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.lg))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 12)
    }

    private func itemCreatedAt(_ item: HomeFeedItem) -> String? {
        let relativeTime = formatRelativeTimestamp(item.post.post.createdAt)
        return relativeTime.isEmpty ? nil : relativeTime
    }

    private var currentFeedCacheKey: String {
        let authScope = sessionManager.isAuthenticated
            ? "auth:\(sessionManager.user?.id ?? "unknown")"
            : "public"
        return "\(authScope):\(sortMode)"
    }

    private var hasFreshFeed: Bool {
        guard
            !feedItems.isEmpty,
            lastFeedCacheKey == currentFeedCacheKey,
            let lastFeedLoadedAt
        else { return false }
        return Date().timeIntervalSince(lastFeedLoadedAt) < Self.feedStaleInterval
    }

    private func markFeedFresh(cacheKey: String) {
        lastFeedLoadedAt = Date()
        lastFeedCacheKey = cacheKey
    }

    private func handlePullRefreshDistance(_ distance: CGFloat) {
        if distance < 1 {
            didTriggerPullRefresh = false
            return
        }

        guard
            distance >= Self.pullRefreshTriggerDistance,
            !didTriggerPullRefresh,
            !isRefreshingFeed,
            !isLoading
        else { return }

        didTriggerPullRefresh = true
        Task { await refreshFeed() }
    }

    private func refreshFeed() async {
        guard !isRefreshingFeed else { return }
        isRefreshingFeed = true
        defer { isRefreshingFeed = false }
        await loadFeed(force: true, showsBlockingLoader: false)
    }

    private func loadFeed(force: Bool = false, showsBlockingLoader: Bool = true) async {
        if !force, hasFreshFeed {
            isLoading = false
            errorMessage = nil
            return
        }

        let cacheKey = currentFeedCacheKey
        isLoading = showsBlockingLoader && feedItems.isEmpty
        errorMessage = nil
        paginationError = nil

        do {
            let response = try await ApiClient.shared.publicHomeFeed(sort: sortMode)
            feedItems = response.items
            cachePostSnapshots(from: response.items)
            nextCursor = response.nextCursor
            resetLiveRoomFeedState()

            if sessionManager.isAuthenticated {
                if let authResponse = try? await ApiClient.shared.homeFeed(sort: sortMode) {
                    feedItems = authResponse.items
                    cachePostSnapshots(from: authResponse.items)
                    nextCursor = authResponse.nextCursor
                    markFeedFresh(cacheKey: cacheKey)
                    resetLiveRoomFeedState()
                }
                await prewarmGateEligibility()
            } else {
                markFeedFresh(cacheKey: cacheKey)
            }
        } catch let error as ApiError {
            if feedItems.isEmpty {
                errorMessage = error.displayMessage
            } else {
                paginationError = error.displayMessage
            }
        } catch {
            if feedItems.isEmpty {
                errorMessage = error.localizedDescription
            } else {
                paginationError = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func loadMore(cursor: String) async {
        isLoadingMore = true
        paginationError = nil

        do {
            let response: HomeFeedResponse
            if sessionManager.isAuthenticated {
                response = try await ApiClient.shared.homeFeed(cursor: cursor, sort: sortMode)
            } else {
                response = try await ApiClient.shared.publicHomeFeed(cursor: cursor, sort: sortMode)
            }

            let existingIds = Set(feedItems.map { $0.id })
            let newItems = response.items.filter { !existingIds.contains($0.id) }
            feedItems.append(contentsOf: newItems)
            cachePostSnapshots(from: newItems)
            nextCursor = response.nextCursor
            await prewarmGateEligibility()
        } catch let error as ApiError {
            paginationError = error.displayMessage
        } catch {
            paginationError = error.localizedDescription
        }
        isLoadingMore = false
    }

    private func liveRoomAutoplayTaskKey(for post: Post) -> String {
        [
            post.id,
            post.anchorLiveRoom ?? "none",
            post.anchorLiveRoomStatus ?? "unknown",
            activeFeedLiveRoomId ?? "inactive",
            sessionManager.isAuthenticated ? "auth" : "public"
        ].joined(separator: ":")
    }

    private func liveRoomDidAppear(_ post: Post) {
        guard let liveRoomId = post.anchorLiveRoom else { return }
        if !visibleLiveRoomIds.contains(liveRoomId) {
            visibleLiveRoomIds.append(liveRoomId)
        }
        if activeFeedLiveRoomId == nil && liveRoomIsLive(post) {
            activeFeedLiveRoomId = liveRoomId
        }
    }

    private func liveRoomDidDisappear(_ post: Post) {
        guard let liveRoomId = post.anchorLiveRoom else { return }
        visibleLiveRoomIds.removeAll { $0 == liveRoomId }
        if activeFeedLiveRoomId == liveRoomId {
            activeFeedLiveRoomId = nil
            liveViewerSessionsById[liveRoomId] = nil
            promoteNextVisibleLiveRoom()
        }
    }

    private func liveRoomIsLive(_ post: Post) -> Bool {
        post.anchorLiveRoomStatus == "live"
    }

    private func liveRoomIsPlaying(_ post: Post) -> Bool {
        guard let liveRoomId = post.anchorLiveRoom else { return false }
        return activeFeedLiveRoomId == liveRoomId && liveViewerSessionsById[liveRoomId] != nil
    }

    private func promoteNextVisibleLiveRoom() {
        guard activeFeedLiveRoomId == nil else { return }
        for liveRoomId in visibleLiveRoomIds {
            if let post = postForLiveRoomId(liveRoomId), liveRoomIsLive(post) {
                activeFeedLiveRoomId = liveRoomId
                return
            }
        }
    }

    private func postForLiveRoomId(_ liveRoomId: String) -> Post? {
        for item in feedItems where item.post.post.anchorLiveRoom == liveRoomId {
            return item.post.post
        }
        return nil
    }

    private func prepareAutoplayLiveRoom(for post: Post) async {
        guard
            let liveRoomId = post.anchorLiveRoom,
            let communityId = post.communityId
        else { return }

        guard liveRoomIsLive(post) else { return }
        if activeFeedLiveRoomId == nil && visibleLiveRoomIds.contains(liveRoomId) {
            activeFeedLiveRoomId = liveRoomId
        }
        guard activeFeedLiveRoomId == liveRoomId else { return }
        guard liveViewerSessionsById[liveRoomId] == nil, !attachingLiveRoomIds.contains(liveRoomId) else { return }

        attachingLiveRoomIds.insert(liveRoomId)
        defer { attachingLiveRoomIds.remove(liveRoomId) }

        do {
            let access = try await fetchHomeLiveRoomAccess(communityId: communityId, liveRoomId: liveRoomId)
            guard access.room.status == "live", access.access.allowed else { return }
            let attach = try await attachHomeLiveRoomViewer(communityId: communityId, liveRoomId: liveRoomId)
            guard attach.room.status == "live", attach.access.allowed else { return }
            liveViewerSessionsById[liveRoomId] = attach
        } catch {
            #if DEBUG
            print("[HomeView] quiet live-room autoplay failed: \(error)")
            #endif
            return
        }
    }

    private func fetchHomeLiveRoomAccess(communityId: String, liveRoomId: String) async throws -> LiveRoomAccessResponse {
        if sessionManager.isAuthenticated {
            do {
                return try await ApiClient.shared.getLiveRoomAccess(communityId: communityId, liveRoomId: liveRoomId)
            } catch let error as ApiError where error.isAuthError || error.isNotFound {
                return try await ApiClient.shared.publicLiveRoomAccess(communityId: communityId, liveRoomId: liveRoomId)
            }
        }
        return try await ApiClient.shared.publicLiveRoomAccess(communityId: communityId, liveRoomId: liveRoomId)
    }

    private func attachHomeLiveRoomViewer(communityId: String, liveRoomId: String) async throws -> LiveRoomViewerAttachResponse {
        if sessionManager.isAuthenticated {
            do {
                return try await ApiClient.shared.viewerAttachLiveRoom(communityId: communityId, liveRoomId: liveRoomId)
            } catch let error as ApiError where error.isAuthError || error.isNotFound {
                return try await ApiClient.shared.publicViewerAttachLiveRoom(communityId: communityId, liveRoomId: liveRoomId)
            }
        }
        return try await ApiClient.shared.publicViewerAttachLiveRoom(communityId: communityId, liveRoomId: liveRoomId)
    }

    private func renewHomeLiveRoomViewer(liveRoomId: String, uid: UInt) async throws -> LiveRoomViewerAttachResponse {
        guard let session = liveViewerSessionsById[liveRoomId] else {
            throw ApiError.unknown("Live room session is not active")
        }

        let renewed: LiveRoomViewerAttachResponse
        if sessionManager.isAuthenticated {
            do {
                renewed = try await ApiClient.shared.viewerRenewLiveRoom(communityId: session.room.community, liveRoomId: liveRoomId, uid: uid)
            } catch let error as ApiError where error.isAuthError || error.isNotFound {
                renewed = try await ApiClient.shared.publicViewerRenewLiveRoom(communityId: session.room.community, liveRoomId: liveRoomId, uid: uid)
            }
        } else {
            renewed = try await ApiClient.shared.publicViewerRenewLiveRoom(communityId: session.room.community, liveRoomId: liveRoomId, uid: uid)
        }

        liveViewerSessionsById[liveRoomId] = renewed
        return renewed
    }

    private func resetLiveRoomFeedState() {
        attachingLiveRoomIds = []
        liveViewerSessionsById = [:]
        visibleLiveRoomIds = []
        activeFeedLiveRoomId = nil
    }

    private func toggleFollow(_ community: HomeFeedCommunitySummary) async {
        do {
            if community.viewerFollowing == true {
                _ = try await ApiClient.shared.unfollowCommunity(communityId: community.id)
            } else {
                _ = try await ApiClient.shared.followCommunity(communityId: community.id)
            }
            await loadFeed(force: true)
        } catch {}
    }

    private func voteOnPost(item: HomeFeedItem, value: Int) async {
        let postId = item.post.post.id
        guard !votingPostIds.contains(postId) else { return }
        votingPostIds.insert(postId)
        actionError = nil
        await gateController.runPostVote(
            isAuthenticated: sessionManager.isAuthenticated,
            userId: sessionManager.user?.id,
            communityId: item.community.id,
            communityName: item.community.displayName,
            postId: postId,
            value: value,
            showSignIn: { showSignIn = true },
            perform: { altchaPayload in
                _ = try await ApiClient.shared.votePost(id: postId, value: value, altchaPayload: altchaPayload)
                await loadFeed(force: true)
            }
        )
        if let inlineError = gateController.inlineError {
            actionError = inlineError
        }
        votingPostIds.remove(postId)
    }

    private func prewarmGateEligibility() async {
        await gateController.prewarmEligibility(
            communityIds: feedItems.map { $0.community.id },
            isAuthenticated: sessionManager.isAuthenticated,
            userId: sessionManager.user?.id
        )
    }

    private func cachePostSnapshots(from items: [HomeFeedItem]) {
        PostSnapshotCache.shared.store(contentsOf: items.map(\.post))
    }

    private func postScore(_ post: LocalizedPostResponse) -> Int {
        let upvotes = post.upvoteCount ?? post.post.upvoteCount ?? 0
        let downvotes = post.downvoteCount ?? post.post.downvoteCount ?? 0
        return upvotes - downvotes
    }
}

private struct HomeFeedPullRefreshOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct HomeSidebarSheet: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    @Binding var isPresented: Bool
    let sortMode: String
    let onSelectSort: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Pirate")
                        .font(PirateTokens.Typography.h3)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        PirateIconView(icon: .x, size: 16, color: colors.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(colors.surfaceSubtle, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close navigation")
                }

                sidebarSection("Feed") {
                    sortRow(label: "Best", icon: .flame, sort: "best")
                    sortRow(label: "New", icon: .sparkle, sort: "new")
                    sortRow(label: "Top", icon: .trendUp, sort: "top")
                }

                sidebarSection("Pirate") {
                    navigationRow(label: "Home", icon: .house, route: .home)
                    navigationRow(label: "Your Communities", icon: .users, route: .yourCommunities)
                    navigationRow(label: "Create Community", icon: .plus, route: .createCommunity)
                }

                sidebarSection("Account") {
                    navigationRow(label: "Wallet", icon: .wallet, route: .wallet)
                    navigationRow(label: "Chat", icon: .chatCircle, route: .chat)
                    navigationRow(label: "Notifications", icon: .bell, route: .notifications)
                    navigationRow(label: "Profile", icon: .userCircle, route: .me)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(colors.bgPage.ignoresSafeArea())
    }

    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(PirateTokens.Typography.smallStrong)
                .foregroundStyle(colors.textSecondary.opacity(0.7))
                .padding(.horizontal, 4)
            VStack(spacing: 4) {
                content()
            }
        }
    }

    private func sortRow(label: String, icon: PirateIcon, sort: String) -> some View {
        Button {
            onSelectSort(sort)
        } label: {
            rowContent(label: label, icon: icon, trailingIcon: sortMode == sort ? .check : nil)
        }
        .buttonStyle(.plain)
    }

    private func navigationRow(label: String, icon: PirateIcon, route: PirateRoute) -> some View {
        NavigationLink(value: route) {
            rowContent(label: label, icon: icon, trailingIcon: .caretRight)
        }
        .simultaneousGesture(TapGesture().onEnded { isPresented = false })
        .buttonStyle(.plain)
    }

    private func rowContent(label: String, icon: PirateIcon, trailingIcon: PirateIcon?) -> some View {
        HStack(spacing: 12) {
            PirateIconView(icon: icon, size: 21, color: colors.textSecondary)
                .frame(width: 24)
            Text(label)
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(colors.textPrimary)
            Spacer()
            if let trailingIcon {
                PirateIconView(icon: trailingIcon, size: 15, color: colors.textSecondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
        .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))
    }
}
