import SwiftUI

enum ProfilePageTab: String, CaseIterable, Identifiable {
    case overview
    case posts
    case comments
    case wallet

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: return "Overview"
        case .posts: return "Posts"
        case .comments: return "Comments"
        case .wallet: return "Wallet"
        }
    }

    var activityValue: String? {
        switch self {
        case .overview, .posts, .comments: return rawValue
        case .wallet: return nil
        }
    }

    var pirateIcon: PirateIcon {
        switch self {
        case .overview: return .squaresFour
        case .posts: return .article
        case .comments: return .comments
        case .wallet: return .wallet
        }
    }
}

enum ProfileViewerContext {
    case selfProfile
    case publicProfile
}

struct ProfileStat: Identifiable {
    let label: String
    let value: String

    var id: String { label }
}

struct ProfilePageData {
    let profile: Profile
    let viewerContext: ProfileViewerContext
    let stats: [ProfileStat]
    let walletAddress: String?
    let activityHandle: String?
    let activityUserId: String?

    init(
        profile: Profile,
        viewerContext: ProfileViewerContext,
        stats: [ProfileStat]? = nil,
        walletAddress: String? = nil,
        activityHandle: String? = nil,
        activityUserId: String? = nil
    ) {
        self.profile = profile
        self.viewerContext = viewerContext
        self.stats = stats ?? profile.followStats()
        self.walletAddress = walletAddress
        self.activityHandle = activityHandle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.activityUserId = activityUserId?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    var hasWalletTab: Bool {
        walletAddress?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var messageTarget: String? {
        let inbox = profile.xmtpInbox?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let inbox, !inbox.isEmpty { return inbox }
        let wallet = walletAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        return wallet?.isEmpty == false ? wallet : nil
    }
}

struct PirateProfilePage: View {
    @Environment(\.pirateColors) private var colors

    let data: ProfilePageData
    var pageTitle: String?
    var editDestination: PirateRoute?
    var viewerFollows = false
    var followBusy = false
    var followDisabled = true
    var onEditProfile: (() -> Void)?
    var onToggleFollow: (() -> Void)?
    var onMessage: ((String) -> Void)?

    @State private var selectedTab: ProfilePageTab = .overview
    @State private var activityResponse: ProfileActivityResponse?
    @State private var loadedActivityTab: ProfilePageTab?
    @State private var isLoadingActivity = false
    @State private var isLoadingMoreActivity = false
    @State private var activityErrorMessage: String?

    private var tabs: [ProfilePageTab] {
        ProfilePageTab.allCases.filter { tab in
            switch tab {
            case .wallet:
                return data.hasWalletTab
            case .comments:
                return data.viewerContext != .selfProfile || data.hasWalletTab
            default:
                return true
            }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                if let pageTitle {
                    MobilePageHeader(pageTitle)
                }

                ProfileIdentityHero(
                    data: data,
                    editDestination: editDestination,
                    viewerFollows: viewerFollows,
                    followBusy: followBusy,
                    followDisabled: followDisabled,
                    onEditProfile: onEditProfile,
                    onToggleFollow: onToggleFollow,
                    onMessage: onMessage
                )

                ProfileTabBar(
                    tabs: tabs,
                    selectedTab: selectedTab,
                    onSelect: { selectedTab = $0 }
                )

                selectedPanel
            }
            .padding(.bottom, 32)
        }
        .background(colors.bgPage)
        .onChange(of: data.hasWalletTab) { _, hasWalletTab in
            if selectedTab == .wallet && !hasWalletTab {
                selectedTab = .overview
            }
            if selectedTab == .comments && data.viewerContext == .selfProfile && !hasWalletTab {
                selectedTab = .overview
            }
        }
        .task(id: "\(data.profile.userId):\(data.activityHandle ?? ""):\(data.activityUserId ?? ""):\(selectedTab.rawValue)") {
            await loadActivity(reset: true)
        }
    }

    @ViewBuilder
    private var selectedPanel: some View {
        switch selectedTab {
        case .overview:
            ProfileActivityPanel(
                tab: selectedTab,
                response: currentActivityResponse,
                isLoading: isLoadingActivity,
                isLoadingMore: isLoadingMoreActivity,
                errorMessage: activityErrorMessage,
                onRetry: { Task { await loadActivity(reset: true) } },
                onLoadMore: { Task { await loadActivity(reset: false) } }
            )
        case .posts:
            ProfileActivityPanel(
                tab: selectedTab,
                response: currentActivityResponse,
                isLoading: isLoadingActivity,
                isLoadingMore: isLoadingMoreActivity,
                errorMessage: activityErrorMessage,
                onRetry: { Task { await loadActivity(reset: true) } },
                onLoadMore: { Task { await loadActivity(reset: false) } }
            )
        case .comments:
            ProfileActivityPanel(
                tab: selectedTab,
                response: currentActivityResponse,
                isLoading: isLoadingActivity,
                isLoadingMore: isLoadingMoreActivity,
                errorMessage: activityErrorMessage,
                onRetry: { Task { await loadActivity(reset: true) } },
                onLoadMore: { Task { await loadActivity(reset: false) } }
            )
        case .wallet:
            WalletPanel(walletAddress: data.walletAddress)
        }
    }

    private var currentActivityResponse: ProfileActivityResponse? {
        loadedActivityTab == selectedTab ? activityResponse : nil
    }

    private func loadActivity(reset: Bool) async {
        guard let activityValue = selectedTab.activityValue else { return }
        if isLoadingActivity || isLoadingMoreActivity { return }
        if reset {
            isLoadingActivity = true
            activityErrorMessage = nil
        } else {
            guard let cursor = currentActivityResponse?.nextCursor else { return }
            isLoadingMoreActivity = true
            activityErrorMessage = nil
            await loadActivityPage(activityValue: activityValue, cursor: cursor)
            isLoadingMoreActivity = false
            return
        }

        await loadActivityPage(activityValue: activityValue, cursor: nil)
        isLoadingActivity = false
    }

    private func loadActivityPage(activityValue: String, cursor: String?) async {
        do {
            let response: ProfileActivityResponse
            switch data.viewerContext {
            case .selfProfile:
                response = try await ApiClient.shared.myProfileActivity(tab: activityValue, cursor: cursor, limit: 20)
            case .publicProfile:
                if let handle = data.activityHandle {
                    response = try await ApiClient.shared.publicProfileActivity(handle: handle, tab: activityValue, cursor: cursor, limit: 20)
                } else if let userId = data.activityUserId {
                    response = try await ApiClient.shared.profileActivity(userId: userId, tab: activityValue, cursor: cursor, limit: 20)
                } else {
                    activityResponse = ProfileActivityResponse(tab: activityValue, posts: [], comments: [], overviewItems: [], nextCursor: nil)
                    loadedActivityTab = selectedTab
                    return
                }
            }

            if cursor == nil || loadedActivityTab != selectedTab {
                activityResponse = response
            } else {
                activityResponse = mergedActivityResponse(existing: activityResponse, next: response)
            }
            cachePostSnapshots(from: response)
            loadedActivityTab = selectedTab
        } catch let error as ApiError {
            activityErrorMessage = error.displayMessage
        } catch {
            activityErrorMessage = error.localizedDescription
        }
    }

    private func mergedActivityResponse(existing: ProfileActivityResponse?, next: ProfileActivityResponse) -> ProfileActivityResponse {
        guard let existing else { return next }
        return ProfileActivityResponse(
            tab: next.tab,
            posts: existing.posts + next.posts,
            comments: existing.comments + next.comments,
            overviewItems: existing.overviewItems + next.overviewItems,
            nextCursor: next.nextCursor
        )
    }

    private func cachePostSnapshots(from response: ProfileActivityResponse) {
        var posts = response.posts.map(\.post)
        posts.append(contentsOf: response.comments.map(\.threadRootPost))
        for item in response.overviewItems {
            switch item {
            case .post(let post):
                posts.append(post.post)
            case .comment(let comment):
                posts.append(comment.threadRootPost)
            }
        }
        PostSnapshotCache.shared.store(contentsOf: posts)
    }
}

private struct ProfileIdentityHero: View {
    @Environment(\.pirateColors) private var colors

    let data: ProfilePageData
    let editDestination: PirateRoute?
    let viewerFollows: Bool
    let followBusy: Bool
    let followDisabled: Bool
    let onEditProfile: (() -> Void)?
    let onToggleFollow: (() -> Void)?
    let onMessage: ((String) -> Void)?

    private var profile: Profile { data.profile }
    private var displayHandle: String { profile.displayHandle }
    private var displayName: String {
        profile.displayName?.nilIfEmpty
            ?? displayHandle.nilIfEmpty
            ?? "Profile"
    }
    private var profileSeed: String {
        profile.userId.nilIfEmpty ?? displayHandle.nilIfEmpty ?? displayName
    }

    var body: some View {
        VStack(spacing: 0) {
            ProfileCoverView(
                coverRef: profile.coverRef,
                displayName: displayName,
                handle: displayHandle,
                userId: profileSeed
            )
            .frame(height: 144)
            .clipped()

            VStack(alignment: .leading, spacing: 14) {
                ProfileAvatar(
                    avatarRef: profile.avatarRef,
                    displayName: displayName,
                    seed: profileSeed,
                    size: 80
                )
                .offset(y: -40)
                .padding(.bottom, -40)

                VStack(alignment: .leading, spacing: 8) {
                    Text(displayName)
                        .font(PirateTokens.Typography.h2)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if !data.stats.isEmpty {
                        HStack(spacing: 14) {
                            ForEach(data.stats.prefix(3)) { stat in
                                HStack(spacing: 4) {
                                    Text(stat.value)
                                        .font(PirateTokens.Typography.bodyStrong)
                                        .foregroundStyle(colors.textPrimary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Text(stat.label.lowercased())
                                        .font(PirateTokens.Typography.body)
                                        .foregroundStyle(colors.textSecondary)
                                        .lineLimit(1)
                                }
                                .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }

                    ProfileHeroAction(
                        viewerContext: data.viewerContext,
                        messageTarget: data.messageTarget,
                        editDestination: editDestination,
                        viewerFollows: viewerFollows,
                        followBusy: followBusy,
                        followDisabled: followDisabled,
                        onEditProfile: onEditProfile,
                        onToggleFollow: onToggleFollow,
                        onMessage: onMessage
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PirateTokens.pageGutter)
            .padding(.top, 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProfileHeroAction: View {
    let viewerContext: ProfileViewerContext
    let messageTarget: String?
    let editDestination: PirateRoute?
    let viewerFollows: Bool
    let followBusy: Bool
    let followDisabled: Bool
    let onEditProfile: (() -> Void)?
    let onToggleFollow: (() -> Void)?
    let onMessage: ((String) -> Void)?

    var body: some View {
        switch viewerContext {
        case .selfProfile:
            if let editDestination {
                NavigationLink(value: editDestination) {
                    ProfileButtonLabel(text: "Edit", icon: .pencilSimple, tone: .primary)
                }
                .buttonStyle(.plain)
            } else if let onEditProfile {
                Button(action: onEditProfile) {
                    ProfileButtonLabel(text: "Edit", icon: .pencilSimple, tone: .primary)
                }
                .buttonStyle(.plain)
            }
        case .publicProfile:
            HStack(spacing: 10) {
                Button {
                    onToggleFollow?()
                } label: {
                    ProfileButtonLabel(
                        text: viewerFollows ? "Following" : "Follow",
                        icon: .userPlus,
                        tone: viewerFollows ? .secondary : .primary,
                        loading: followBusy
                    )
                }
                .buttonStyle(.plain)
                .disabled(followBusy || followDisabled || onToggleFollow == nil)

                if let messageTarget {
                    if let onMessage {
                        Button {
                            onMessage(messageTarget)
                        } label: {
                            ProfileButtonLabel(text: "Message", icon: .chatCircle, tone: .secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink(value: PirateRoute.chatTarget(messageTarget)) {
                            ProfileButtonLabel(text: "Message", icon: .chatCircle, tone: .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    ProfileButtonLabel(text: "Message", icon: .chatCircle, tone: .secondary)
                        .opacity(0.55)
                }
            }
        }
    }
}

private enum ProfileButtonTone {
    case primary
    case secondary
}

private struct ProfileButtonLabel: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii

    let text: String
    let icon: PirateIcon?
    let tone: ProfileButtonTone
    var loading = false

    private var foreground: Color {
        tone == .primary ? colors.textOnAccent : colors.textPrimary
    }

    private var background: Color {
        tone == .primary ? colors.accentBrand : colors.surfaceSubtle
    }

    var body: some View {
        HStack(spacing: 8) {
            if loading {
                ProgressView()
                    .controlSize(.small)
                    .tint(foreground)
            }
            if let icon {
                PirateIconView(icon: icon, size: 17, color: foreground)
            }
            Text(text)
                .font(PirateTokens.Typography.bodyStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(background, in: RoundedRectangle(cornerRadius: radii.full))
        .overlay(RoundedRectangle(cornerRadius: radii.full).stroke(colors.borderSoft, lineWidth: tone == .primary ? 0 : 1))
    }
}

private struct ProfileCoverView: View {
    let coverRef: String?
    let displayName: String
    let handle: String
    let userId: String

    var body: some View {
        ZStack {
            DefaultProfileCover(displayName: displayName, handle: handle, userId: userId)

            if let coverURL = ApiClient.shared.publicMediaURL(from: coverRef), coverURL.scheme != "data" {
                AsyncImage(url: coverURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                    }
                }
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.05),
                    Color.clear,
                    Color.black.opacity(0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

private struct DefaultProfileCover: View {
    let displayName: String
    let handle: String
    let userId: String

    private var pair: (Color, Color) {
        let seed = "\(userId):\(displayName.nilIfEmpty ?? handle):profile-cover"
        return defaultCoverColors[Int(stableHash(seed) % UInt32(defaultCoverColors.count))]
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [pair.0, pair.1], startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 132, height: 132)
                .offset(x: 32, y: -18)

            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 72)
            }
        }
    }
}

private struct ProfileAvatar: View {
    @Environment(\.pirateColors) private var colors

    let avatarRef: String?
    let displayName: String
    let seed: String
    let size: CGFloat

    var body: some View {
        AvatarView(avatarRef: avatarRef, size: size, fallbackLabel: displayName, fallbackSeed: seed)
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(colors.bgPage, lineWidth: 4))
    }
}

private struct ProfileTabBar: View {
    @Environment(\.pirateColors) private var colors

    let tabs: [ProfilePageTab]
    let selectedTab: ProfilePageTab
    let onSelect: (ProfilePageTab) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(tabs) { tab in
                    Button {
                        onSelect(tab)
                    } label: {
                        VStack(spacing: 12) {
                            PirateIconView(
                                icon: tab.pirateIcon,
                                size: 22,
                                color: tab == selectedTab ? colors.textPrimary : colors.textSecondary
                            )
                                .frame(height: 24)

                            Rectangle()
                                .fill(tab == selectedTab ? colors.accentBrand : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tab.label)
                }
            }
            .padding(.horizontal, PirateTokens.pageGutter)

            Divider()
                .overlay(colors.borderSoft)
        }
    }
}

private struct ProfileActivityPanel: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii

    let tab: ProfilePageTab
    let response: ProfileActivityResponse?
    let isLoading: Bool
    let isLoadingMore: Bool
    let errorMessage: String?
    let onRetry: () -> Void
    let onLoadMore: () -> Void

    private var overviewItems: [ProfileActivityItem] {
        response?.overviewItems ?? []
    }

    private var posts: [ProfileActivityPostPage] {
        response?.posts ?? []
    }

    private var comments: [ProfileActivityCommentPage] {
        response?.comments ?? []
    }

    private var isEmpty: Bool {
        switch tab {
        case .overview: return overviewItems.isEmpty
        case .posts: return posts.isEmpty
        case .comments: return comments.isEmpty
        case .wallet: return true
        }
    }

    private var emptyCopy: String {
        switch tab {
        case .overview: return "No activity yet"
        case .posts: return "No posts yet"
        case .comments: return "No comments yet"
        case .wallet: return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(colors.borderSoft)

            if let errorMessage {
                VStack(alignment: .leading, spacing: 10) {
                    Text(errorMessage)
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.accentDanger)
                    Button("Try again", action: onRetry)
                        .font(PirateTokens.Typography.smallStrong)
                        .foregroundStyle(colors.accentBrand)
                }
                .padding(.vertical, 18)
            } else if isLoading && isEmpty {
                ProgressView()
                    .tint(colors.accentBrand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else if isEmpty {
                Text(emptyCopy)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 28)
            } else {
                activityContent
            }

            if response?.nextCursor != nil {
                Button(action: onLoadMore) {
                    HStack {
                        if isLoadingMore {
                            ProgressView().tint(colors.accentBrand)
                        }
                        Text(isLoadingMore ? "Loading..." : "Load more")
                            .font(PirateTokens.Typography.bodyStrong)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(colors.accentBrand)
                    .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.lg))
                }
                .buttonStyle(.plain)
                .disabled(isLoadingMore)
                .padding(.vertical, 14)
            }

            Divider().overlay(colors.borderSoft)
        }
        .padding(.horizontal, PirateTokens.pageGutter)
    }

    @ViewBuilder
    private var activityContent: some View {
        switch tab {
        case .overview:
            ForEach(overviewItems) { item in
                switch item {
                case .post(let post):
                    ProfilePostActivityRow(item: post)
                case .comment(let comment):
                    ProfileCommentActivityRow(item: comment)
                }
                Divider().overlay(colors.borderSoft)
            }
        case .posts:
            ForEach(posts) { post in
                ProfilePostActivityRow(item: post)
                Divider().overlay(colors.borderSoft)
            }
        case .comments:
            ForEach(comments) { comment in
                ProfileCommentActivityRow(item: comment)
                Divider().overlay(colors.borderSoft)
            }
        case .wallet:
            EmptyView()
        }
    }
}

private struct ProfilePostActivityRow: View {
    @Environment(\.pirateColors) private var colors

    let item: ProfileActivityPostPage

    private var post: LocalizedPostResponse { item.post }
    private var community: Community { item.community.community }

    var body: some View {
        NavigationLink(value: PirateRoute.post(post.id)) {
            VStack(alignment: .leading, spacing: 10) {
                ProfileActivityMetaLine(community: community, created: item.created ?? post.post.createdAt)

                if let title = postTitle(post) {
                    Text(title)
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(3)
                }

                if let body = postBody(post), !body.isEmpty, body != postTitle(post) {
                    Text(body)
                        .font(PirateTokens.Typography.body)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(5)
                }

                let mediaItem = PiratePostMediaItem.primary(for: post.post)
                if mediaItem != nil {
                    PostMediaView(post: post.post, context: .feed)
                }

                if post.post.linkUrl != nil {
                    PostLinkPreview(post: post.post, compact: true, showsPreviewImage: mediaItem == nil)
                }

                HStack(spacing: 10) {
                    VotePill(score: postScore(post), voteValue: post.viewerVote, disabled: true, onVote: { _ in })
                    CommentCountPill(count: post.commentCount ?? post.post.commentCount ?? 0)
                    Spacer()
                }
                .padding(.top, 2)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileCommentActivityRow: View {
    @Environment(\.pirateColors) private var colors

    let item: ProfileActivityCommentPage

    private var comment: CommentListItem { item.comment }
    private var community: Community { item.community.community }

    var body: some View {
        NavigationLink(value: PirateRoute.post(item.threadRootPost.id)) {
            VStack(alignment: .leading, spacing: 10) {
                ProfileActivityMetaLine(community: community, created: item.created ?? comment.comment.createdAt)

                if let body = comment.translatedBody ?? comment.comment.body, !body.isEmpty {
                    Text(body)
                        .font(PirateTokens.Typography.body)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(5)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("On post")
                        .font(PirateTokens.Typography.smallStrong)
                        .foregroundStyle(colors.textSecondary)

                    Text(postTitle(item.threadRootPost) ?? "Untitled post")
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(2)
                }
                .padding(12)
                .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: 8))

                HStack(spacing: 10) {
                    VotePill(score: commentScore(comment.comment), voteValue: comment.viewerVote, disabled: true, onVote: { _ in })
                    Spacer()
                }
                .padding(.top, 2)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

private struct ProfileActivityMetaLine: View {
    @Environment(\.pirateColors) private var colors

    let community: Community
    let created: String?

    var body: some View {
        HStack(spacing: 10) {
            CommunityAvatarView(
                avatarRef: community.avatarRef,
                communityId: community.id,
                displayName: community.displayName,
                size: 28
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(community.displayName)
                    .font(PirateTokens.Typography.smallStrong)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)

                Text(profileActivityMetaText(community: community, created: created))
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
    }
}

private struct WalletPanel: View {
    @Environment(\.pirateColors) private var colors

    let walletAddress: String?

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(colors.borderSoft)
            HStack {
                Text("Wallet")
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textSecondary)
                Spacer()
                Text(walletAddress?.shortAddress ?? "")
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.vertical, 18)
            Divider().overlay(colors.borderSoft)
        }
        .padding(.horizontal, PirateTokens.pageGutter)
    }
}

private let defaultCoverColors: [(Color, Color)] = [
    (Color(red: 0x17 / 255.0, green: 0x4A / 255.0, blue: 0x53 / 255.0), Color(red: 0xB5 / 255.0, green: 0x6B / 255.0, blue: 0x34 / 255.0)),
    (Color(red: 0x51 / 255.0, green: 0x33 / 255.0, blue: 0x5F / 255.0), Color(red: 0x1F / 255.0, green: 0x7A / 255.0, blue: 0x6D / 255.0)),
    (Color(red: 0x25 / 255.0, green: 0x47 / 255.0, blue: 0x6A / 255.0), Color(red: 0x8A / 255.0, green: 0x3D / 255.0, blue: 0x4F / 255.0)),
    (Color(red: 0x5A / 255.0, green: 0x3F / 255.0, blue: 0x2B / 255.0), Color(red: 0x27 / 255.0, green: 0x63 / 255.0, blue: 0x5F / 255.0)),
    (Color(red: 0x6E / 255.0, green: 0x3A / 255.0, blue: 0x46 / 255.0), Color(red: 0x2E / 255.0, green: 0x5A / 255.0, blue: 0x77 / 255.0))
]

private func stableHash(_ value: String) -> UInt32 {
    var hash: UInt32 = 2_166_136_261
    for scalar in value.unicodeScalars {
        hash ^= scalar.value
        hash = hash &* 16_777_619
    }
    return hash
}

private func postTitle(_ post: LocalizedPostResponse) -> String? {
    post.translatedTitle ?? post.post.title ?? post.post.caption
}

private func postBody(_ post: LocalizedPostResponse) -> String? {
    post.translatedBody ?? post.post.body
}

private func postScore(_ post: LocalizedPostResponse) -> Int {
    let upvotes = post.upvoteCount ?? post.post.upvoteCount ?? 0
    let downvotes = post.downvoteCount ?? post.post.downvoteCount ?? 0
    return upvotes - downvotes
}

private func commentScore(_ comment: Comment) -> Int {
    let upvotes = comment.upvoteCount ?? 0
    let downvotes = comment.downvoteCount ?? 0
    return upvotes - downvotes
}

private func profileActivityMetaText(community: Community, created: String?) -> String {
    let communityLabel = communityPresentationLabel(
        communityId: community.communityId,
        displayName: community.displayName,
        routeSlug: community.routeSlug,
        namespaceVerificationId: community.namespaceVerificationId
    )
    guard let created, !created.isEmpty else {
        return communityLabel
    }
    let relative = profileActivityRelativeTime(from: created)
    guard !relative.isEmpty else {
        return communityLabel
    }
    return "\(relative) · \(communityLabel)"
}

private func profileActivityRelativeTime(from timestamp: String) -> String {
    let date: Date?
    if let epoch = Double(timestamp), epoch > 0 {
        date = Date(timeIntervalSince1970: epoch)
    } else {
        date = ISO8601DateFormatter().date(from: timestamp)
    }
    guard let date else { return "" }

    let seconds = max(0, Int(Date().timeIntervalSince(date)))
    if seconds < 60 { return "now" }
    if seconds < 3_600 { return "\(seconds / 60)m ago" }
    if seconds < 86_400 { return "\(seconds / 3_600)h ago" }
    if seconds < 604_800 { return "\(seconds / 86_400)d ago" }
    return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
}

private extension Profile {
    var displayHandle: String {
        let label = primaryPublicHandle?.label.nilIfEmpty ?? globalHandle?.label.nilIfEmpty ?? ""
        if label.isEmpty { return "" }
        return label.contains(".") ? label : "\(label).pirate"
    }

    func followStats() -> [ProfileStat] {
        [
            ProfileStat(label: "Followers", value: String(followerCount ?? 0)),
            ProfileStat(label: "Following", value: String(followingCount ?? 0))
        ]
    }
}

private extension String {
    var initial: String {
        String(trimmingCharacters(in: .whitespacesAndNewlines).first ?? "?").uppercased()
    }

    var shortAddress: String {
        guard count > 12 else { return self }
        return "\(prefix(6))...\(suffix(4))"
    }
}
