import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    var sessionManager: SessionManager

    @State private var feedItems: [HomeFeedItem] = []
    @State private var nextCursor: String?
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var paginationError: String?
    @State private var actionError: String?
    @State private var sortMode: String = "best"
    @State private var showSignIn = false
    @State private var showSidebar = false
    @State private var votingPostIds: Set<String> = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isLoading {
                    LoadingView()
                        .frame(height: 200)
                } else if let error = errorMessage, feedItems.isEmpty {
                    ErrorView(message: error, retry: loadFeed)
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
        .background(colors.bgPage)
        .navigationTitle("Pirate")
        .inlineNavigationBarTitle()
        #if os(iOS)
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
        .refreshable {
            await loadFeed()
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
                    Task { await loadFeed() }
                }
            )
        }
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
        VStack(alignment: .leading, spacing: 10) {
            communityHeader(item.community)

            NavigationLink(value: PirateRoute.post(item.post.post.id)) {
                feedItemPostPreview(item)
            }
            .buttonStyle(.plain)

            feedItemFooter(item.post)
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 16)
        .background(colors.bgPage)
        .overlay(Rectangle().fill(colors.borderSoft).frame(height: 0.5), alignment: .bottom)
    }

    private func feedItemPostPreview(_ item: HomeFeedItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = item.post.post.title {
                Text(title)
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(4)
            }

            if item.post.post.anchorLiveRoom != nil {
                liveRoomBadge(status: item.post.post.anchorLiveRoomStatus)
            }

            if let body = item.post.post.body, !body.isEmpty, body != item.post.post.title {
                Text(body)
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(5)
            }

            let mediaItem = PiratePostMediaItem.primary(for: item.post.post)
            if mediaItem != nil {
                PostMediaView(post: item.post.post, context: .feed)
            }

            if item.post.post.linkUrl != nil {
                PostLinkPreview(post: item.post.post, compact: true, showsPreviewImage: mediaItem == nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func liveRoomBadge(status: String?) -> some View {
        let isLive = status == "live"
        let label: String = {
            switch status {
            case "live": return "Live now"
            case "ended": return "Ended"
            case "canceled": return "Canceled"
            default: return "Scheduled"
            }
        }()

        return HStack(spacing: 6) {
            Image(systemName: isLive ? "dot.radiowaves.left.and.right" : "calendar")
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(PirateTokens.Typography.smallStrong)
        }
        .foregroundStyle(isLive ? colors.accentDanger : colors.accentBrand)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(isLive ? colors.surfaceDanger : colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.full))
        .overlay(RoundedRectangle(cornerRadius: radii.full).stroke(colors.borderSoft, lineWidth: 1))
    }

    private func communityHeader(_ community: HomeFeedCommunitySummary) -> some View {
        HStack(spacing: 8) {
            AvatarView(avatarRef: community.avatarRef, size: 20, fallbackLabel: community.displayName)
            NavigationLink(value: PirateRoute.community(community.id)) {
                Text(formatCommunityRouteLabel(communityId: community.id, routeSlug: community.routeSlug))
                    .font(PirateTokens.Typography.smallStrong)
                    .foregroundStyle(colors.textSecondary)
            }
            .buttonStyle(.plain)

            if let createdAt = itemCreatedAt(community) {
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

    private func feedItemFooter(_ post: LocalizedPostResponse) -> some View {
        HStack(spacing: 10) {
            VotePill(
                score: postScore(post),
                voteValue: post.viewerVote,
                disabled: votingPostIds.contains(post.post.id),
                onVote: { value in
                    Task { await voteOnPost(postId: post.post.id, value: value) }
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

    private func itemCreatedAt(_ community: HomeFeedCommunitySummary) -> String? {
        return nil
    }

    private func loadFeed() async {
        isLoading = true
        errorMessage = nil
        paginationError = nil

        do {
            let response = try await ApiClient.shared.publicHomeFeed(sort: sortMode)
            feedItems = response.items
            nextCursor = response.nextCursor

            if sessionManager.isAuthenticated {
                if let authResponse = try? await ApiClient.shared.homeFeed(sort: sortMode) {
                    feedItems = authResponse.items
                    nextCursor = authResponse.nextCursor
                }
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
            nextCursor = response.nextCursor
        } catch let error as ApiError {
            paginationError = error.displayMessage
        } catch {
            paginationError = error.localizedDescription
        }
        isLoadingMore = false
    }

    private func toggleFollow(_ community: HomeFeedCommunitySummary) async {
        do {
            if community.viewerFollowing == true {
                _ = try await ApiClient.shared.unfollowCommunity(communityId: community.id)
            } else {
                _ = try await ApiClient.shared.followCommunity(communityId: community.id)
            }
            await loadFeed()
        } catch {}
    }

    private func voteOnPost(postId: String, value: Int) async {
        guard sessionManager.isAuthenticated else {
            showSignIn = true
            return
        }
        guard !votingPostIds.contains(postId) else { return }
        votingPostIds.insert(postId)
        actionError = nil
        do {
            _ = try await ApiClient.shared.votePost(id: postId, value: value)
            await loadFeed()
        } catch let error as ApiError {
            actionError = error.displayMessage
        } catch {
            actionError = error.localizedDescription
        }
        votingPostIds.remove(postId)
    }

    private func postScore(_ post: LocalizedPostResponse) -> Int {
        let upvotes = post.upvoteCount ?? post.post.upvoteCount ?? 0
        let downvotes = post.downvoteCount ?? post.post.downvoteCount ?? 0
        return upvotes - downvotes
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
