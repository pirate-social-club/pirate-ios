import SwiftUI
#if os(iOS)
import UIKit
#endif

struct CommunityView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    @Environment(\.dismiss) private var dismiss
    @Environment(\.navigatePirateRoute) private var navigatePirateRoute
    var sessionManager: SessionManager

    let communityId: String

    @State private var communityPreview: CommunityPreview?
    @State private var posts: [LocalizedPostResponse] = []
    @State private var nextCursor: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var actionError: String?
    @State private var showSignIn = false
    @State private var votingPostIds: Set<String> = []
    @State private var sortMode = "best"
    @State private var activeTab = "feed"
    @State private var isLoadingMore = false
    @State private var paginationError: String?
    @State private var joinEligibility: JoinEligibility?
    @State private var readMode: PirateReadMode = .publicRead
    @State private var gateController = CommunityInteractionGateController()
    @State private var selfVerificationRequest: CommunitySelfVerificationRequest?
    @State private var isCommunityDetailActive = true

    private var resolvedCommunityId: String {
        communityPreview?.community.id ?? communityId
    }

    private var viewportWidth: CGFloat {
        #if os(iOS)
        return max(UIScreen.main.bounds.width, 320)
        #else
        return 390
        #endif
    }

    private var pageContentWidth: CGFloat {
        max(viewportWidth - PirateTokens.pageGutter * 2, 0)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let community = communityPreview {
                    communityHeader(community)
                    communityTabs
                    if let actionError {
                        inlineError(actionError)
                    }
                    if activeTab == "feed" {
                        if let paginationError {
                            inlineError(paginationError)
                        }
                        postsList
                    } else {
                        aboutSections(community)
                    }
                } else if isLoading {
                    LoadingView()
                } else if let error = errorMessage {
                    ErrorView(message: error, retry: loadCommunity)
                }
            }
            .frame(width: viewportWidth, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
        .background(colors.bgPage)
        .navigationTitle("")
        .inlineNavigationBarTitle()
        .navigationBarBackButtonHidden(true)
        .tint(colors.textPrimary)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    PirateIconView(icon: .caretLeft, size: 22, color: colors.textPrimary)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    beginComposePost()
                } label: {
                    PirateIconView(icon: .plus, size: 21, color: colors.textPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create post")
                if activeTab == "feed" {
                    sortMenu
                }
            }
        }
        .task {
            await loadCommunity()
        }
        .sheet(isPresented: $showSignIn) {
            SignInDrawer(sessionManager: sessionManager, isPresented: $showSignIn)
        }
        .sheet(isPresented: Binding(
            get: { isCommunityDetailActive && gateController.isSheetPresented },
            set: { isPresented in
                if !isPresented { gateController.closeSheet() }
            }
        )) {
            CommunityInteractionGateSheet(
                controller: gateController,
                onSelfVerificationRequested: { request in
                    selfVerificationRequest = CommunitySelfVerificationRequest(
                        intent: request.intent,
                        requestedCapabilities: request.requestedCapabilities,
                        verificationRequirements: request.verificationRequirements
                    )
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
            isCommunityDetailActive = true
            Task { await gateController.resumeWithRetry() }
        }
        .onDisappear {
            isCommunityDetailActive = false
            gateController.closeSheet()
        }
    }

    private func beginComposePost() {
        gateController.closeSheet()
        guard sessionManager.isAuthenticated else {
            showSignIn = true
            return
        }
        guard !canOpenComposerImmediately else {
            openComposer()
            return
        }

        Task {
            await gateController.runPostCompose(
                isAuthenticated: sessionManager.isAuthenticated,
                userId: sessionManager.user?.id,
                communityId: resolvedCommunityId,
                communityName: communityPreview?.community.displayName ?? "this community",
                showSignIn: { showSignIn = true },
                continueAfterJoin: {
                    openComposer()
                }
            )
        }
    }

    private var canOpenComposerImmediately: Bool {
        let status = joinEligibility?.status ?? communityPreview?.viewerMembershipStatus
        return status == "already_joined"
            || status == "member"
            || status == "owner"
            || status == "admin"
            || status == "moderator"
    }

    private func openComposer() {
        gateController.closeSheet()
        navigatePirateRoute(.composePost(resolvedCommunityId))
    }

    private func beginCommunityJoin() {
        gateController.closeSheet()
        guard sessionManager.isAuthenticated else {
            showSignIn = true
            return
        }

        Task {
            await gateController.runCommunityJoin(
                isAuthenticated: sessionManager.isAuthenticated,
                userId: sessionManager.user?.id,
                communityId: resolvedCommunityId,
                communityName: communityPreview?.community.displayName ?? "this community",
                showSignIn: { showSignIn = true },
                didJoin: {
                    Task { await refreshCommunityHeader() }
                }
            )
        }
    }

    private func communityHeader(_ preview: CommunityPreview) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let url = ApiClient.shared.publicMediaURL(from: preview.community.bannerRef) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Rectangle().fill(colors.bgElevated)
                        }
                    }
                } else {
                    LinearGradient(
                        colors: [colors.bgElevated, colors.surfaceSubtle],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: pageContentWidth, height: 144)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: radii.x2l))
            .overlay(RoundedRectangle(cornerRadius: radii.x2l).stroke(colors.borderSoft, lineWidth: 1))
            .padding(.horizontal, PirateTokens.pageGutter)

            VStack(alignment: .leading, spacing: 12) {
                CommunityAvatarView(
                    avatarRef: preview.community.avatarRef,
                    communityId: preview.community.id,
                    displayName: preview.community.displayName,
                    size: 72
                )
                    .padding(.top, -36)

                VStack(alignment: .leading, spacing: 4) {
                    CommunityNameLabel(
                        text: preview.community.displayName,
                        isUnverified: !isCommunityRouteVerified(
                            routeSlug: preview.community.routeSlug,
                            namespaceVerificationId: preview.community.namespaceVerificationId
                        ),
                        font: PirateTokens.Typography.h2,
                        color: colors.textPrimary,
                        iconSize: 18,
                        lineLimit: 2
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isCommunityRouteVerified(
                        routeSlug: preview.community.routeSlug,
                        namespaceVerificationId: preview.community.namespaceVerificationId
                    ) {
                        Text(routeLabel(for: preview.community))
                            .font(PirateTokens.Typography.body)
                            .foregroundStyle(colors.textSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if let description = preview.community.description, !description.isEmpty {
                    Text(description)
                        .font(PirateTokens.Typography.body)
                        .foregroundStyle(colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 16) {
                    if let memberCount = preview.community.memberCount {
                        communityMeta("\(memberCount) members")
                    }
                    if let followerCount = preview.community.followerCount {
                        communityMeta("\(followerCount) followers")
                    }
                }

                communityHeaderActions(preview)
            }
            .frame(width: pageContentWidth, alignment: .leading)
            .padding(.horizontal, PirateTokens.pageGutter)
            .padding(.bottom, 18)
        }
        .frame(width: viewportWidth, alignment: .leading)
    }

    private func communityMeta(_ text: String) -> some View {
        Text(text)
            .font(PirateTokens.Typography.smallStrong)
            .foregroundStyle(colors.textSecondary)
    }

    private func communityHeaderActions(_ preview: CommunityPreview) -> some View {
        HStack(spacing: 12) {
            followButton(preview)
                .frame(maxWidth: .infinity)
            joinButton(preview)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private func followButton(_ preview: CommunityPreview) -> some View {
        Button {
            if !sessionManager.isAuthenticated {
                showSignIn = true
                return
            }
            Task { await toggleFollow() }
        } label: {
            communityActionPill(
                title: preview.viewerFollowing == true ? "Following" : "Follow",
                tone: preview.viewerFollowing == true ? .secondary : .primary
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func joinButton(_ preview: CommunityPreview) -> some View {
        let status = joinEligibility?.status ?? preview.viewerMembershipStatus
        if status == "already_joined" || status == "member" {
            communityActionPill(title: "Joined", tone: .secondary)
        } else if status == "verification_required" || status == "gate_failed" {
            if requiresProofOfWork(joinEligibility) {
                Button {
                    beginCommunityJoin()
                } label: {
                    communityActionPill(title: joinButtonTitle(for: status), tone: .secondary)
                }
                .buttonStyle(.plain)
            } else if verificationProvider(for: joinEligibility) == "self" {
                Button {
                    if !sessionManager.isAuthenticated {
                        showSignIn = true
                        return
                    }
                    selfVerificationRequest = selfVerificationRequest(for: joinEligibility)
                } label: {
                    communityActionPill(title: joinButtonTitle(for: status), tone: .secondary)
                }
                .buttonStyle(.plain)
            } else if let route = verificationRoute(for: joinEligibility) {
                NavigationLink(value: route) {
                    communityActionPill(title: joinButtonTitle(for: status), tone: .secondary)
                }
                .buttonStyle(.plain)
            } else {
                communityActionPill(title: joinButtonTitle(for: status), tone: .secondary)
            }
        } else {
            Button {
                beginCommunityJoin()
            } label: {
                communityActionPill(title: joinButtonTitle(for: status), tone: .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private enum CommunityActionTone {
        case primary
        case secondary
    }

    private func communityActionPill(title: String, tone: CommunityActionTone, loading: Bool = false) -> some View {
        HStack(spacing: 8) {
            if loading {
                ProgressView()
                    .controlSize(.small)
                    .tint(tone == .primary ? colors.textOnAccent : colors.accentBrand)
            }
            Text(title)
                .font(PirateTokens.Typography.bodyStrong)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
        }
        .foregroundStyle(tone == .primary ? colors.textOnAccent : colors.textPrimary)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(tone == .primary ? colors.accentBrand : colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.full))
        .overlay(RoundedRectangle(cornerRadius: radii.full).stroke(colors.borderSoft, lineWidth: 1))
    }

    private var communityTabs: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabButton(title: "Feed", value: "feed")
                tabButton(title: "About", value: "about")
            }
            .padding(.horizontal, PirateTokens.pageGutter)
            Rectangle()
                .fill(colors.borderSoft)
                .frame(height: 0.5)
                .padding(.horizontal, PirateTokens.pageGutter)
        }
    }

    private func tabButton(title: String, value: String) -> some View {
        Button {
            activeTab = value
        } label: {
            VStack(spacing: 12) {
                Text(title)
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(activeTab == value ? colors.textPrimary : colors.textSecondary)
                Rectangle()
                    .fill(activeTab == value ? colors.accentDanger : Color.clear)
                    .frame(height: 2)
            }
            .padding(.top, 12)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var sortMenu: some View {
        Menu {
            sortMenuButton("Best", value: "best")
            sortMenuButton("New", value: "new")
            sortMenuButton("Top", value: "top")
        } label: {
            PirateIconView(icon: .slidersHorizontal, size: 22, color: colors.textPrimary)
        }
        .accessibilityLabel("Sort feed")
    }

    private func sortMenuButton(_ title: String, value: String) -> some View {
        Button {
            changeSort(value)
        } label: {
            Text(title)
        }
        .disabled(sortMode == value)
    }

    private var postsList: some View {
        LazyVStack(spacing: 0) {
            if posts.isEmpty && !isLoading {
                Text("No posts yet.")
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, PirateTokens.pageGutter)
                    .padding(.vertical, 18)
            } else {
                ForEach(posts) { localizedPost in
                    postRow(localizedPost)
                }
            }

            if isLoading && !posts.isEmpty {
                ProgressView()
                    .tint(colors.accentBrand)
                    .padding()
            }

            if let nextCursor {
                loadMoreButton(nextCursor: nextCursor)
            }
        }
    }

    private func postRow(_ post: LocalizedPostResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            postAuthorHeader(post)

            NavigationLink(value: PirateRoute.post(post.id)) {
                postPreviewContent(post)
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                VotePill(
                    score: postScore(post),
                    voteValue: post.viewerVote,
                    disabled: votingPostIds.contains(post.post.id),
                    onVote: { value in
                        Task { await voteOnPost(postId: post.post.id, value: value) }
                    }
                )

                CommentCountPill(
                    count: post.commentCount ?? post.post.commentCount ?? 0,
                    onComment: {
                        openComments(for: post)
                    }
                )

                Spacer()
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 16)
        .background(colors.bgPage)
        .overlay(Rectangle().fill(colors.borderSoft).frame(height: 0.5), alignment: .bottom)
    }

    @ViewBuilder
    private func postAuthorHeader(_ localizedPost: LocalizedPostResponse) -> some View {
        if let route = authorProfileRoute(for: localizedPost.post) {
            NavigationLink(value: route) {
                postAuthorHeaderContent(localizedPost)
            }
            .buttonStyle(.plain)
        } else {
            postAuthorHeaderContent(localizedPost)
        }
    }

    private func postAuthorHeaderContent(_ localizedPost: LocalizedPostResponse) -> some View {
        let post = localizedPost.post
        let metaLine = postMetaLine(for: post)

        return HStack(spacing: 10) {
            AvatarView(
                avatarRef: post.authorAvatarRef,
                size: 38,
                fallbackLabel: authorLabel(for: post),
                fallbackSeed: post.authorUserId ?? authorLabel(for: post)
            )

            HStack(spacing: 5) {
                Text(authorLabel(for: post))
                    .font(PirateTokens.Typography.smallStrong)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                CommunityRoleIconBadgeView(role: localizedPost.authorCommunityRole, size: 14)
                    .fixedSize()

                Text("·")
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.textSecondary)

                Text(metaLine)
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityLabel("View \(authorLabel(for: post)) profile")
    }

    private func postPreviewContent(_ post: LocalizedPostResponse) -> some View {
        return VStack(alignment: .leading, spacing: 10) {
            if let title = postTitle(post) {
                Text(title)
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(4)
            }

            if let body = postBody(post), !body.isEmpty, body != postTitle(post) {
                Text(body)
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(5)
            }

            let isSongPost = post.post.postType == "song"
            let mediaItem = PiratePostMediaItem.primary(for: post.post)
            if isSongPost {
                SongPostView(localizedPost: post, context: .feed)
            } else if mediaItem != nil {
                PostMediaView(post: post.post, context: .feed)
            }

            let showsLinkPreviewImage = mediaItem == nil && !isSongPost
            if PostLinkPreview.canRender(post: post.post, showsPreviewImage: showsLinkPreviewImage) {
                PostLinkPreview(post: post.post, compact: true, showsPreviewImage: showsLinkPreviewImage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func inlineError(_ message: String) -> some View {
        Text(message)
            .font(PirateTokens.Typography.caption)
            .foregroundStyle(colors.accentDanger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PirateTokens.pageGutter)
            .padding(.vertical, 8)
    }

    private func aboutSections(_ preview: CommunityPreview) -> some View {
        let description = preview.community.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let gates = sidebarGateItems(preview)
        let links = activeReferenceLinks(preview)
        let rules = activeRules(preview)
        let flairs = activeFlairs(preview)
        let hasStats = preview.community.followerCount != nil || preview.community.memberCount != nil
        let charity = communityCharity(preview)
        let hasDetails = (description?.isEmpty == false)
            || hasStats
            || preview.owner != nil
            || !preview.moderators.isEmpty
            || charity != nil
            || !gates.isEmpty
            || !links.isEmpty
            || !rules.isEmpty
            || !flairs.isEmpty

        return VStack(alignment: .leading, spacing: 22) {
            if let description, !description.isEmpty {
                aboutDetailSection(title: "About") {
                    Text(description)
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if hasStats {
                aboutStatsGrid(preview)
            }

            if let owner = preview.owner {
                aboutDetailSection(title: "Owner") {
                    roleHolderRow(owner)
                }
            }

            if !preview.moderators.isEmpty {
                aboutDetailSection(title: "Moderators") {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(preview.moderators) { moderator in
                            roleHolderRow(moderator)
                        }
                    }
                }
            }

            if let charity {
                aboutDetailSection(title: "Charity") {
                    charityRow(charity)
                }
            }

            if !gates.isEmpty {
                aboutDetailSection(title: "Access gates") {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(gates.indices, id: \.self) { index in
                            gateRow(gates[index], showsDivider: index < gates.count - 1)
                        }
                    }
                }
            }

            if !links.isEmpty {
                aboutDetailSection(title: "Links") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(links.indices, id: \.self) { index in
                            aboutLinkRow(links[index])
                        }
                    }
                }
            }

            if !rules.isEmpty {
                aboutDetailSection(title: "Rules") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(rules.indices, id: \.self) { index in
                            aboutRuleRow(rule: rules[index], index: index)
                        }
                    }
                }
            }

            if !flairs.isEmpty {
                aboutDetailSection(title: "Tags") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(flairs) { flair in
                            flairRow(flair)
                        }
                    }
                }
            }

            if !hasDetails {
                Text("No community details yet.")
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 16)
    }

    private func aboutStatsGrid(_ preview: CommunityPreview) -> some View {
        HStack(alignment: .top, spacing: 16) {
            if let followerCount = preview.community.followerCount {
                aboutStat(value: compactCount(followerCount), label: "Followers")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let memberCount = preview.community.memberCount {
                aboutStat(value: compactCount(memberCount), label: "Citizens")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func aboutStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(PirateTokens.Typography.h3)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(PirateTokens.Typography.caption)
                .foregroundStyle(colors.textSecondary)
        }
    }

    @ViewBuilder
    private func roleHolderRow(_ holder: CommunityRoleHolder) -> some View {
        if let route = roleHolderProfileRoute(holder) {
            NavigationLink(value: route) {
                roleHolderRowContent(holder)
            }
            .buttonStyle(.plain)
        } else {
            roleHolderRowContent(holder)
        }
    }

    private func roleHolderRowContent(_ holder: CommunityRoleHolder) -> some View {
        HStack(spacing: 10) {
            AvatarView(
                avatarRef: holder.avatarRef,
                size: 36,
                fallbackLabel: roleHolderName(holder),
                fallbackSeed: holder.user
            )

            HStack(spacing: 6) {
                Text(roleHolderDisplayLabel(holder))
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)

                CommunityRoleIconBadgeView(role: holder.role, size: 16)
            }

            Spacer(minLength: 10)

            if let country = holder.nationalityBadgeCountry, !country.isEmpty {
                Text(country.uppercased())
                    .font(PirateTokens.Typography.smallStrong)
                    .foregroundStyle(colors.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityLabel("View \(roleHolderDisplayLabel(holder)) profile")
    }

    private func charityRow(_ partner: CommunityDonationPartner) -> some View {
        let content = HStack(spacing: 10) {
            AvatarView(avatarRef: partner.imageURL, size: 36, fallbackLabel: partner.displayName)
            Text(partner.displayName ?? "Charity partner")
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 10)
            PirateIconView(icon: .caretRight, size: 18, color: colors.textSecondary)
        }
        .padding(.vertical, 4)

        return Group {
            if let ref = partner.providerPartnerRef,
               let url = URL(string: "https://app.endaoment.org/orgs/\(ref)") {
                Link(destination: url) { content }
            } else {
                content
            }
        }
    }

    private func gateRow(_ item: CommunitySidebarGateItem, showsDivider: Bool = true) -> some View {
        HStack(spacing: 12) {
            PirateIconView(icon: gateIcon(for: item), size: 20, color: colors.textSecondary)
                .frame(width: 36, height: 36)

            Text(item.label)
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            gateStatusIcon(item.status)
        }
        .frame(minHeight: 44)
        .padding(.vertical, 3)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Rectangle()
                    .fill(colors.borderSoft.opacity(0.7))
                    .frame(height: 0.5)
            }
        }
    }

    @ViewBuilder
    private func gateStatusIcon(_ status: CommunityGateStatus) -> some View {
        switch status {
        case .met:
            ZStack {
                Circle().fill(colors.accentBrand)
                PirateIconView(icon: .check, size: 12, color: colors.textOnAccent)
            }
            .frame(width: 20, height: 20)
        case .unknown, .unmet:
            Circle()
                .stroke(colors.textSecondary.opacity(0.75), lineWidth: 1.6)
                .frame(width: 20, height: 20)
        }
    }

    private func flairRow(_ flair: CommunityFlairDefinition) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(colors.surfaceSubtle)
                .overlay(Circle().stroke(colors.borderSoft, lineWidth: 1))
                .frame(width: 12, height: 12)
            Text(flair.label ?? "Tag")
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 10)
        }
        .padding(.vertical, 2)
    }

    private func aboutDetailSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            aboutSectionLabel(title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func aboutSectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(PirateTokens.Typography.smallStrong)
            .foregroundStyle(colors.textSecondary)
    }

    private func aboutLinkRow(_ link: CommunityReferenceLink) -> some View {
        Group {
            if let urlString = link.url, let url = URL(string: urlString) {
                Link(destination: url) {
                    aboutLinkContent(link)
                }
            } else {
                aboutLinkContent(link)
            }
        }
        .padding(.vertical, 4)
    }

    private func aboutLinkContent(_ link: CommunityReferenceLink) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(referenceLinkLabel(link))
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
                if let url = link.url, !url.isEmpty {
                    Text(url)
                        .font(PirateTokens.Typography.small)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 12)
            if link.verified == true {
                PirateIconView(icon: .check, size: 18, color: colors.accentBrand)
            }
        }
        .contentShape(Rectangle())
    }

    private func aboutRuleRow(rule: CommunityRule, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(index + 1)")
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)
                    .frame(width: 18, alignment: .leading)
                Text(rule.title)
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let body = rule.body, !body.isEmpty {
                Text(body)
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 28)
            }
        }
        .padding(.vertical, 4)
    }

    private func activeRules(_ preview: CommunityPreview) -> [CommunityRule] {
        (preview.rules ?? [])
            .filter { isActiveStatus($0.status) }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
    }

    private func activeReferenceLinks(_ preview: CommunityPreview) -> [CommunityReferenceLink] {
        (preview.referenceLinks ?? [])
            .filter { isActiveStatus($0.linkStatus) }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) }
    }

    private func activeFlairs(_ preview: CommunityPreview) -> [CommunityFlairDefinition] {
        guard preview.flairPolicy?.flairEnabled == true else { return [] }
        return preview.flairPolicy?.definitions
            .filter { isActiveStatus($0.status) }
            .sorted { ($0.position ?? Int.max) < ($1.position ?? Int.max) } ?? []
    }

    private func isActiveStatus(_ status: String?) -> Bool {
        guard let status else { return true }
        return status == "active"
    }

    private func compactCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }

    private func referenceLinkLabel(_ link: CommunityReferenceLink) -> String {
        link.label ?? link.metadata?.displayName ?? platformLabel(link.platform) ?? "Link"
    }

    private func platformLabel(_ platform: String?) -> String? {
        guard let platform else { return nil }
        switch platform {
        case "apple_music":
            return "Apple Music"
        case "official_website":
            return "Website"
        case "musicbrainz":
            return "MusicBrainz"
        case "soundcloud":
            return "SoundCloud"
        default:
            return platform
                .split(separator: "_")
                .map { $0.prefix(1).uppercased() + String($0.dropFirst()) }
                .joined(separator: " ")
        }
    }

    private func roleHolderName(_ holder: CommunityRoleHolder) -> String {
        holder.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? holder.handle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? holder.user
    }

    private func roleHolderDisplayLabel(_ holder: CommunityRoleHolder) -> String {
        roleHolderHandleLabel(holder) ?? roleHolderName(holder)
    }

    private func roleHolderHandleLabel(_ holder: CommunityRoleHolder) -> String? {
        guard let handle = holder.handle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else {
            return nil
        }
        if handle.lowercased().hasPrefix("u/") {
            return String(handle.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
        return handle
    }

    private func roleHolderProfileRoute(_ holder: CommunityRoleHolder) -> PirateRoute? {
        if let handle = roleHolderHandleLabel(holder) {
            return .publicProfile(handle)
        }
        guard let userId = holder.user.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else {
            return nil
        }
        return .user(userId)
    }

    private func communityCharity(_ preview: CommunityPreview) -> CommunityDonationPartner? {
        guard preview.donationPolicyMode != "none" else { return nil }
        return preview.donationPartner
    }

    private func loadMoreButton(nextCursor: String) -> some View {
        Button {
            Task { await loadMore(cursor: nextCursor) }
        } label: {
            HStack {
                if isLoadingMore {
                    ProgressView().tint(colors.accentBrand)
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
        .disabled(isLoadingMore)
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 12)
    }

    private func loadCommunity() async {
        isLoading = true
        errorMessage = nil
        actionError = nil
        paginationError = nil
        joinEligibility = nil
        do {
            let loaded = try await loadCommunityPreview()
            let preview = loaded.preview
            readMode = loaded.readMode
            communityPreview = preview
            let resolvedCommunityId = preview.community.id
            if sessionManager.isAuthenticated {
                joinEligibility = try? await ApiClient.shared.joinEligibility(communityId: resolvedCommunityId)
            } else {
                joinEligibility = nil
            }

            do {
                let loadedPosts = try await loadCommunityPosts(
                    communityId: resolvedCommunityId,
                    readMode: loaded.readMode
                )
                posts = loadedPosts.response.items
                PostSnapshotCache.shared.store(contentsOf: loadedPosts.response.items)
                nextCursor = loadedPosts.response.nextCursor
                readMode = loadedPosts.readMode
            } catch let error as ApiError {
                posts = []
                nextCursor = nil
                paginationError = error.displayMessage
            } catch {
                posts = []
                nextCursor = nil
                paginationError = error.localizedDescription
            }
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func refreshCommunityHeader() async {
        actionError = nil
        do {
            let loaded = try await loadCommunityPreview()
            let preview = loaded.preview
            readMode = loaded.readMode
            communityPreview = preview
            if sessionManager.isAuthenticated {
                joinEligibility = try? await ApiClient.shared.joinEligibility(communityId: preview.community.id)
            } else {
                joinEligibility = nil
            }
        } catch let error as ApiError {
            actionError = error.displayMessage
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func loadCommunityPreview() async throws -> (preview: CommunityPreview, readMode: PirateReadMode) {
        if sessionManager.isAuthenticated {
            do {
                return (try await ApiClient.shared.community(id: communityId), .authenticated)
            } catch let error as ApiError where error.isAuthError || error.isNotFound || error.isForbidden {
                return (try await ApiClient.shared.publicCommunity(id: communityId), .publicRead)
            }
        }

        return (try await ApiClient.shared.publicCommunity(id: communityId), .publicRead)
    }

    private func loadCommunityPosts(
        communityId: String,
        cursor: String? = nil,
        readMode requestedReadMode: PirateReadMode
    ) async throws -> (response: PostListResponse, readMode: PirateReadMode) {
        if sessionManager.isAuthenticated && requestedReadMode == .authenticated {
            do {
                let response = try await ApiClient.shared.communityPosts(
                    communityId: communityId,
                    cursor: cursor,
                    sort: sortMode,
                    limit: 25
                )
                return (response, .authenticated)
            } catch let error as ApiError where error.isAuthError || error.isNotFound || error.isForbidden {
                let response = try await ApiClient.shared.publicCommunityPosts(
                    communityId: communityId,
                    cursor: cursor,
                    sort: sortMode,
                    limit: 25
                )
                return (response, .publicRead)
            }
        }

        let response = try await ApiClient.shared.publicCommunityPosts(
            communityId: communityId,
            cursor: cursor,
            sort: sortMode,
            limit: 25
        )
        return (response, .publicRead)
    }

    private func loadMore(cursor: String) async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        paginationError = nil
        do {
            let resolvedCommunityId = communityPreview?.community.id ?? communityId
            let loadedPosts = try await loadCommunityPosts(
                communityId: resolvedCommunityId,
                cursor: cursor,
                readMode: readMode
            )
            let response = loadedPosts.response
            readMode = loadedPosts.readMode
            let existingIds = Set(posts.map { $0.id })
            let newItems = response.items.filter { !existingIds.contains($0.id) }
            posts.append(contentsOf: newItems)
            PostSnapshotCache.shared.store(contentsOf: newItems)
            nextCursor = response.nextCursor
        } catch let error as ApiError {
            paginationError = error.displayMessage
        } catch {
            paginationError = error.localizedDescription
        }
        isLoadingMore = false
    }

    private func changeSort(_ sort: String) {
        guard sort != sortMode else { return }
        sortMode = sort
        Task { await loadCommunity() }
    }

    private func toggleFollow() async {
        guard sessionManager.isAuthenticated else {
            showSignIn = true
            return
        }
        guard let preview = communityPreview else { return }
        actionError = nil
        do {
            if preview.viewerFollowing == true {
                _ = try await ApiClient.shared.unfollowCommunity(communityId: resolvedCommunityId)
            } else {
                _ = try await ApiClient.shared.followCommunity(communityId: resolvedCommunityId)
            }
            await loadCommunity()
        } catch let error as ApiError {
            actionError = error.displayMessage
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func voteOnPost(postId: String, value: Int) async {
        guard !votingPostIds.contains(postId) else { return }
        votingPostIds.insert(postId)
        actionError = nil
        await gateController.runPostVote(
            isAuthenticated: sessionManager.isAuthenticated,
            userId: sessionManager.user?.id,
            communityId: resolvedCommunityId,
            communityName: communityPreview?.community.displayName ?? "this community",
            postId: postId,
            value: value,
            showSignIn: { showSignIn = true },
            perform: { altchaPayload in
                _ = try await ApiClient.shared.votePost(id: postId, value: value, altchaPayload: altchaPayload)
                await loadCommunity()
            }
        )
        if let inlineError = gateController.inlineError {
            actionError = inlineError
        }
        votingPostIds.remove(postId)
    }

    private func openComments(for post: LocalizedPostResponse) {
        actionError = nil
        Task {
            await gateController.runPostReplyAccess(
                isAuthenticated: sessionManager.isAuthenticated,
                userId: sessionManager.user?.id,
                communityId: resolvedCommunityId,
                communityName: communityPreview?.community.displayName ?? "this community",
                showSignIn: { showSignIn = true },
                continueAfterAccess: {
                    navigatePirateRoute(.post(post.id))
                }
            )
            if let inlineError = gateController.inlineError {
                actionError = inlineError
            }
        }
    }

    private func postScore(_ post: LocalizedPostResponse) -> Int {
        let upvotes = post.upvoteCount ?? post.post.upvoteCount ?? 0
        let downvotes = post.downvoteCount ?? post.post.downvoteCount ?? 0
        return upvotes - downvotes
    }

    private func joinButtonTitle(for status: String?) -> String {
        switch status {
        case "requestable":
            return "Request to join"
        case "verification_required":
            switch verificationProvider(for: joinEligibility) {
            case "altcha":
                return "Join"
            case "very":
                return "Verify with Very"
            case "self":
                return "Verify with ID"
            default:
                return "Verify to join"
            }
        case "gate_failed":
            switch verificationProvider(for: joinEligibility) {
            case "altcha":
                return "Join"
            case "very":
                return "Verify with Very"
            case "self":
                return "Verify with ID"
            default:
                return "Not eligible"
            }
        default:
            return "Join"
        }
    }

    private func verificationProvider(for eligibility: JoinEligibility?) -> String? {
        if let normalized = eligibility?.suggestedVerificationProvider?.lowercased() {
            if normalized.contains("altcha") { return "altcha" }
            if normalized.contains("very") { return "very" }
            if normalized.contains("passport") { return "passport" }
            if normalized.contains("self") { return "self" }
            if !normalized.isEmpty { return normalized }
        }
        if requiresProofOfWork(eligibility) {
            return "altcha"
        }
        if requiresSelfVerification(eligibility) {
            return "self"
        }
        if eligibility?.missingCapabilities?.contains("very_unique_human") == true {
            return "very"
        }
        if let normalized = eligibility?.humanVerificationLane?.lowercased(),
           !normalized.isEmpty {
            return normalized
        }
        return nil
    }

    private func requiresProofOfWork(_ eligibility: JoinEligibility?) -> Bool {
        if eligibility?.missingCapabilities?.contains("altcha_pow") == true {
            return true
        }
        return eligibility?.membershipGateSummaries?.contains(where: { $0.gateType == "altcha_pow" }) == true
    }

    private func requiresSelfVerification(_ eligibility: JoinEligibility?) -> Bool {
        let selfCapabilities: Set<String> = ["age_over_18", "nationality", "gender"]
        if eligibility?.missingCapabilities?.contains(where: { selfCapabilities.contains($0) }) == true {
            return true
        }

        let selfGateTypes: Set<String> = ["minimum_age", "nationality", "gender", "self_minimum_age", "self_nationality", "self_excluded_nationality", "self_gender"]
        return eligibility?.membershipGateSummaries?.contains(where: { summary in
            if summary.gateType.map({ selfGateTypes.contains($0) }) == true {
                return true
            }
            return summary.acceptedProviders?.contains(where: { $0.lowercased().contains("self") }) == true
        }) == true
    }

    private func verificationRoute(for eligibility: JoinEligibility?) -> PirateRoute? {
        switch verificationProvider(for: eligibility) {
        case "very":
            return .verificationVery(eligibility?.suggestedVerificationIntent ?? "community_join")
        case "self":
            return .verificationSelf(eligibility?.suggestedVerificationIntent ?? "community_join")
        default:
            return nil
        }
    }

    private func selfVerificationRequest(for eligibility: JoinEligibility?) -> CommunitySelfVerificationRequest {
        CommunitySelfVerificationRequest(
            intent: eligibility?.suggestedVerificationIntent ?? "community_join",
            requestedCapabilities: selfRequestedCapabilities(for: eligibility),
            verificationRequirements: verificationRequirements(for: eligibility?.membershipGateSummaries)
        )
    }

    private func selfRequestedCapabilities(for eligibility: JoinEligibility?) -> [String] {
        let order = ["unique_human", "age_over_18", "nationality", "gender"]
        let missing = Set(eligibility?.missingCapabilities ?? [])
        let capabilities = order.filter { missing.contains($0) }
        return capabilities.isEmpty ? ["unique_human"] : capabilities
    }

    private func verificationRequirements(for summaries: [MembershipGateSummary]?) -> [VerificationRequirement] {
        var requirements: [VerificationRequirement] = []
        let ages = (summaries ?? []).compactMap { gate -> Int? in
            gate.gateType == "minimum_age" ? gate.requiredMinimumAge : nil
        }
        if let minimumAge = ages.max() {
            requirements.append(VerificationRequirement(proofType: "minimum_age", minimumAge: minimumAge))
        }

        let nationalities = Set((summaries ?? []).flatMap { gate -> [String] in
            guard gate.gateType == "nationality" else { return [] }
            let values = gate.requiredValues ?? gate.requiredValue.map { [$0] } ?? []
            return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }.filter { !$0.isEmpty }
        })
        if !nationalities.isEmpty {
            requirements.append(VerificationRequirement(proofType: "nationality", requiredValues: Array(nationalities).sorted()))
        }
        return requirements
    }

    private func routeLabel(for community: Community) -> String {
        formatCommunityRouteLabel(communityId: community.communityId, routeSlug: community.routeSlug)
    }

    private func postTitle(_ post: LocalizedPostResponse) -> String? {
        post.translatedTitle ?? post.post.title ?? post.post.caption
    }

    private func postBody(_ post: LocalizedPostResponse) -> String? {
        post.translatedBody ?? post.post.body
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

    private func postMetaLine(for post: Post) -> String {
        let time = formatRelativeTimestamp(post.createdAt)
        return time.isEmpty ? "now" : time
    }

    private func sidebarGateItems(_ preview: CommunityPreview) -> [CommunitySidebarGateItem] {
        var seenLabels = Set<String>()
        let summaries = joinEligibility?.membershipGateSummaries ?? preview.membershipGateSummaries ?? []

        return summaries.compactMap { gate in
            let gateType = normalizedGateType(gate.gateType)
            let label = sidebarGateLabel(gate)
            guard !seenLabels.contains(label) else { return nil }
            seenLabels.insert(label)
            return CommunitySidebarGateItem(
                gateType: gateType,
                label: label,
                provider: gateProvider(gate),
                status: gateStatus(for: gateType)
            )
        }
    }

    private func sidebarGateLabel(_ gate: MembershipGateSummary) -> String {
        let gateType = normalizedGateType(gate.gateType)
        let values = gateValues(gate)

        switch gateType {
        case "nationality":
            if values.isEmpty {
                return "Nationality verification"
            }
            let countries = values.map(countryDisplayName).joined(separator: ", ")
            return "\(countries) nationality"
        case "excluded_nationality":
            let countries = (gate.excludedValues ?? []).map(countryDisplayName).joined(separator: ", ")
            return countries.isEmpty ? "Excluded nationality configured" : "Excluded nationality: \(countries)"
        case "gender":
            return values.first.map { "Document sex marker \($0)" } ?? "Document sex marker"
        case "age_over_18":
            return "18+"
        case "minimum_age":
            let age = gate.requiredMinimumAge.map(String.init) ?? gate.requiredValue ?? "18"
            return "\(age)+"
        case "unique_human":
            let providers = gate.acceptedProviders ?? []
            if providers.count == 1, providers.first == "very" {
                return "Palm scan"
            }
            if providers.count == 1, providers.first == "self" {
                return "Private ID proof"
            }
            return "Human proof"
        case "altcha_pow":
            return "Proof of work"
        case "wallet_score":
            if let score = gate.minimumScore {
                return "Passport score \(formatGateScore(score))+"
            }
            return "Passport score"
        case "erc721_holding":
            if let address = gate.contractAddress, !address.isEmpty {
                return "Ethereum NFT from \(shortAddress(address))"
            }
            return "Ethereum NFT holder"
        case "erc721_inventory_match":
            let quantity = gate.minQuantity ?? 1
            return "\(quantity) Courtyard \(inventoryAssetLabel(gate))"
        default:
            return humanizedGateType(gate.gateType ?? "Requirement")
        }
    }

    private func gateValues(_ gate: MembershipGateSummary) -> [String] {
        if let values = gate.requiredValues, !values.isEmpty {
            return values
        }
        if let value = gate.requiredValue, !value.isEmpty {
            return [value]
        }
        return []
    }

    private func countryDisplayName(_ value: String) -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let regionCode = isoAlpha3ToAlpha2[normalized] ?? normalized
        return Locale.current.localizedString(forRegionCode: regionCode) ?? normalized
    }

    private func gateProvider(_ gate: MembershipGateSummary) -> String? {
        guard let providers = gate.acceptedProviders, providers.count == 1 else { return nil }
        let provider = providers[0]
        return ["self", "very", "passport"].contains(provider) ? provider : nil
    }

    private func normalizedGateType(_ gateType: String?) -> String {
        switch gateType {
        case "self_nationality":
            return "nationality"
        case "self_excluded_nationality":
            return "excluded_nationality"
        case "self_gender":
            return "gender"
        case "self_minimum_age":
            return "minimum_age"
        case "passport_score":
            return "wallet_score"
        case "wallet_nft":
            return "erc721_holding"
        case "courtyard_inventory":
            return "erc721_inventory_match"
        default:
            return gateType ?? "requirement"
        }
    }

    private func gateStatus(for gateType: String) -> CommunityGateStatus {
        guard let eligibility = joinEligibility else { return .unknown }
        switch eligibility.status {
        case "joinable", "already_joined", "requestable", "pending_request":
            return .met
        case "verification_required", "gate_failed":
            guard let capability = gateCapability(for: gateType) else { return .unknown }
            let missing = Set((eligibility.missingCapabilities ?? []).map(normalizedCapability))
            return missing.contains(capability) ? .unmet : .met
        default:
            return .unknown
        }
    }

    private func gateCapability(for gateType: String) -> String? {
        switch gateType {
        case "unique_human", "age_over_18", "minimum_age", "nationality", "gender", "wallet_score", "altcha_pow", "erc721_holding", "erc721_inventory_match":
            return gateType
        default:
            return nil
        }
    }

    private func normalizedCapability(_ capability: String) -> String {
        let lowercased = capability.lowercased()
        if lowercased.contains("nationality") { return "nationality" }
        if lowercased.contains("gender") { return "gender" }
        if lowercased.contains("minimum_age") { return "minimum_age" }
        if lowercased.contains("age_over_18") { return "age_over_18" }
        if lowercased.contains("unique_human") { return "unique_human" }
        if lowercased.contains("wallet_score") || lowercased.contains("passport_score") { return "wallet_score" }
        if lowercased.contains("altcha") { return "altcha_pow" }
        if lowercased.contains("inventory") { return "erc721_inventory_match" }
        if lowercased.contains("nft") || lowercased.contains("erc721") { return "erc721_holding" }
        return lowercased
    }

    private func gateIcon(for item: CommunitySidebarGateItem) -> PirateIcon {
        switch item.gateType {
        case "nationality":
            return .flag
        case "unique_human", "gender":
            return .userCircle
        case "wallet_score":
            return .trendUp
        case "erc721_holding", "erc721_inventory_match":
            return .wallet
        case "altcha_pow":
            return .sparkle
        case "age_over_18", "minimum_age":
            return .article
        default:
            return .check
        }
    }

    private func formatGateScore(_ score: Double) -> String {
        score.rounded() == score ? String(format: "%.0f", score) : String(score)
    }

    private func shortAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    private func inventoryAssetLabel(_ gate: MembershipGateSummary) -> String {
        if let label = gate.assetFilterLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            return label
        }
        let plural = (gate.minQuantity ?? 1) != 1
        if gate.assetCategory == "watch" {
            return plural ? "watches" : "watch"
        }
        return plural ? "cards" : "card"
    }

    private func humanizedGateType(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + String($0.dropFirst()) }
            .joined(separator: " ")
    }
}
