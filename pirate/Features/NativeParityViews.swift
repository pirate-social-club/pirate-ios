import SwiftUI

private struct SubmitCommunityOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    let detail: String
}

private enum ComposerPostType: String, CaseIterable, Identifiable {
    case text
    case link
    case image
    case video
    case song
    case live

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case .image: return "Image"
        case .video: return "Video"
        case .song: return "Music"
        case .live: return "Live"
        }
    }

    var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .video: return "video"
        case .song: return "music.note"
        case .live: return "antenna.radiowaves.left.and.right"
        }
    }

    var isNativeSubmitEnabled: Bool {
        self == .text || self == .link
    }
}

private struct PublishedPostDestination: Identifiable, Hashable {
    let id: String
}

struct GlobalSubmitView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    var sessionManager: SessionManager

    @State private var communities: [SubmitCommunityOption] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showSignIn = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Text("Choose a community")
                    .font(PirateTokens.Typography.h3)
                    .foregroundStyle(colors.textPrimary)
                    .padding(.horizontal, PirateTokens.pageGutter)
                    .padding(.top, 16)

                if isLoading {
                    LoadingView().frame(height: 180)
                } else if let errorMessage {
                    ErrorView(message: errorMessage, retry: loadCommunities)
                } else if communities.isEmpty {
                    EmptyStateView(
                        icon: "person.3",
                        title: "No communities available",
                        subtitle: "Join or create a community before posting."
                    )
                } else {
                    ForEach(communities) { community in
                        NavigationLink(value: PirateRoute.composePost(community.id)) {
                            PirateCard {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.3")
                                        .foregroundStyle(colors.accentBrand)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(community.displayName)
                                            .font(PirateTokens.Typography.bodyStrong)
                                            .foregroundStyle(colors.textPrimary)
                                        Text(community.detail)
                                            .font(PirateTokens.Typography.small)
                                            .foregroundStyle(colors.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(colors.textSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, PirateTokens.pageGutter)
                    }
                }

                if !sessionManager.isAuthenticated {
                    Button {
                        showSignIn = true
                    } label: {
                        Text("Sign in to post")
                            .font(PirateTokens.Typography.bodyStrong)
                            .foregroundStyle(colors.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, PirateTokens.pageGutter)
                    .padding(.top, 8)
                }
            }
        }
        .background(colors.bgPage)
        .navigationTitle("Create post")
        .inlineNavigationBarTitle()
        .task { await loadCommunities() }
        .refreshable { await loadCommunities() }
        .sheet(isPresented: $showSignIn) {
            SignInDrawer(sessionManager: sessionManager, isPresented: $showSignIn)
        }
    }

    private func loadCommunities() async {
        isLoading = true
        errorMessage = nil
        do {
            var next: [SubmitCommunityOption] = []
            if let handle = sessionManager.profile?.globalHandle?.label {
                let profile = try? await ApiClient.shared.publicProfile(handle: handle)
                next.append(contentsOf: (profile?.createdCommunities ?? []).map {
                    SubmitCommunityOption(
                        id: $0.id,
                        displayName: $0.displayName,
                        detail: $0.routeSlug.map { "c/\($0)" } ?? $0.id
                    )
                })
            }

            let feed = sessionManager.isAuthenticated
                ? try await ApiClient.shared.homeFeed(sort: "best")
                : try await ApiClient.shared.publicHomeFeed(sort: "best")
            next.append(contentsOf: (feed.topCommunities ?? []).map {
                SubmitCommunityOption(
                    id: $0.id,
                    displayName: $0.displayName,
                    detail: "\($0.memberCount ?? 0) members"
                )
            })
            communities = Array(Dictionary(grouping: next, by: \.id).compactMap { $0.value.first })
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct PostComposerView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    @Environment(\.dismiss) private var dismiss
    var sessionManager: SessionManager
    let communityId: String

    @State private var postType = ComposerPostType.text
    @State private var title = ""
    @State private var bodyText = ""
    @State private var linkUrl = ""
    @State private var audienceVisibility = "public"
    @State private var identityMode = "public"
    @State private var communityPreview: CommunityPreview?
    @State private var eligibility: JoinEligibility?
    @State private var isChecking = true
    @State private var isSubmitting = false
    @State private var isJoining = false
    @State private var isLoadingLinkPreview = false
    @State private var linkPreview: LinkPreviewResponse?
    @State private var errorMessage: String?
    @State private var publishedDestination: PublishedPostDestination?

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedBody: String {
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedLinkUrl: String? {
        normalizeHttpUrl(linkUrl)
    }

    private var linkPreviewTaskKey: String {
        "\(postType.rawValue)|\(normalizedLinkUrl ?? "")"
    }

    private var community: Community? {
        communityPreview?.community
    }

    private var communityDisplayName: String {
        community?.displayName ?? communityId
    }

    private var allowsAnonymousIdentity: Bool {
        community?.allowAnonymousIdentity == true
    }

    private var effectiveIdentityMode: String {
        allowsAnonymousIdentity ? identityMode : "public"
    }

    private var anonymousScope: String {
        community?.anonymousIdentityScope ?? "community_stable"
    }

    private var publicAudienceAllowed: Bool {
        guard let rules = community?.gateRules else { return true }
        return !rules.contains { $0.scope == "viewer" && $0.status == "active" }
    }

    private var resolvedVisibility: String {
        publicAudienceAllowed ? audienceVisibility : "members_only"
    }

    private var hasPostingAccess: Bool {
        if eligibility?.status == "already_joined" { return true }
        let membershipStatus = communityPreview?.viewerMembershipStatus
        return membershipStatus == "member" || membershipStatus == "owner" || membershipStatus == "admin" || membershipStatus == "moderator"
    }

    private var hasDraft: Bool {
        switch postType {
        case .text:
            return !trimmedTitle.isEmpty
        case .link:
            return normalizedLinkUrl != nil
        case .image, .video, .song, .live:
            return false
        }
    }

    private var canSubmit: Bool {
        sessionManager.isAuthenticated
            && postType.isNativeSubmitEnabled
            && hasDraft
            && !isChecking
            && !isSubmitting
    }

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    communityPill
                    postTypeTabs
                    accessStatus
                    composerFields
                    audienceSection
                    identitySection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(PirateTokens.Typography.caption)
                            .foregroundStyle(colors.accentDanger)
                    }

                    publishButton
                }
                .padding(PirateTokens.pageGutter)
            }
            .background(colors.bgPage)
            .navigationTitle("Create post")
            .inlineNavigationBarTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await loadComposerContext() }
            .task(id: linkPreviewTaskKey) { await refreshLinkPreview() }
            .navigationDestination(item: $publishedDestination) { destination in
                PostView(sessionManager: sessionManager, postId: destination.id)
            }
        }
    }

    private var communityPill: some View {
        NavigationLink(value: PirateRoute.community(communityId)) {
            HStack(spacing: 12) {
                AvatarView(avatarRef: community?.avatarRef, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Posting in")
                        .font(PirateTokens.Typography.small)
                        .foregroundStyle(colors.textSecondary)
                    Text("c/\(communityDisplayName)")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.textSecondary)
            }
            .padding(12)
            .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.x2l))
        }
        .buttonStyle(.plain)
    }

    private var postTypeTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ComposerPostType.allCases) { type in
                    Button {
                        postType = type
                        errorMessage = nil
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(type.label)
                                .font(PirateTokens.Typography.smallStrong)
                        }
                        .foregroundStyle(postType == type ? colors.textOnAccent : colors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            postType == type ? colors.accentBrand : colors.bgElevated,
                            in: RoundedRectangle(cornerRadius: radii.full)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: radii.full)
                                .stroke(postType == type ? colors.accentBrand : colors.borderDefault, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var accessStatus: some View {
        if isChecking {
            statusCard(
                title: "Checking posting access",
                message: "Loading community permissions.",
                systemImage: "clock",
                tone: .default
            )
        } else if !hasPostingAccess {
            VStack(alignment: .leading, spacing: 12) {
                statusCard(
                    title: "Join this community before posting",
                    message: "You can keep editing this draft. Publishing is available after you join.",
                    systemImage: "lock",
                    tone: .warning
                )
                if eligibility?.joinableNow == true {
                    Button {
                        Task { await joinCommunity() }
                    } label: {
                        HStack {
                            if isJoining { ProgressView().tint(colors.textOnAccent) }
                            Text(isJoining ? "Joining..." : "Join community")
                        }
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                    }
                    .buttonStyle(.plain)
                    .disabled(isJoining)
                    .opacity(isJoining ? 0.55 : 1)
                } else {
                    NavigationLink(value: PirateRoute.community(communityId)) {
                        Text("Open community")
                            .font(PirateTokens.Typography.bodyStrong)
                            .foregroundStyle(colors.accentBrand)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.full))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var composerFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(postType == .link ? "Title (optional)" : "Title", text: $title)
                .textFieldStyle(.plain)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)
                .padding(12)
                .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
                .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderDefault, lineWidth: 1))
                .disabled(isSubmitting)

            if postType == .link {
                TextField("Link URL", text: $linkUrl)
                    .textFieldStyle(.plain)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textPrimary)
                    .padding(12)
                    .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
                    .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderDefault, lineWidth: 1))
                    .disabled(isSubmitting)

                linkPreviewSection
            }

            Text(postType == .link ? "Comment" : "Body")
                .font(PirateTokens.Typography.label)
                .foregroundStyle(colors.textPrimary)

            TextEditor(text: $bodyText)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 180)
                .padding(8)
                .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
                .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderDefault, lineWidth: 1))
                .disabled(isSubmitting)

            if !postType.isNativeSubmitEnabled {
                statusCard(
                    title: "Native upload is next",
                    message: "This tab is visible for parity with the web composer. Text and link publishing are wired in this build.",
                    systemImage: "exclamationmark.triangle",
                    tone: .warning
                )
            }
        }
    }

    @ViewBuilder
    private var linkPreviewSection: some View {
        if isLoadingLinkPreview {
            statusCard(title: "Loading link preview", message: "Fetching the preview from Pirate.", systemImage: "link", tone: .default)
        } else if let linkPreview {
            linkPreviewCard(linkPreview)
        } else if !linkUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && normalizedLinkUrl == nil {
            Text("Enter a valid http or https link.")
                .font(PirateTokens.Typography.caption)
                .foregroundStyle(colors.accentWarning)
        }
    }

    private var audienceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Audience")
                .font(PirateTokens.Typography.label)
                .foregroundStyle(colors.textPrimary)
            Picker("Audience", selection: $audienceVisibility) {
                Text("Public").tag("public")
                Text("Members").tag("members_only")
            }
            .pickerStyle(.segmented)
            .disabled(!publicAudienceAllowed || isSubmitting)

            Text(publicAudienceAllowed ? "Anyone can read this post." : "This community already limits who can read posts.")
                .font(PirateTokens.Typography.caption)
                .foregroundStyle(colors.textSecondary)
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Post as")
                .font(PirateTokens.Typography.label)
                .foregroundStyle(colors.textPrimary)

            Picker("Post as", selection: $identityMode) {
                Text("Public").tag("public")
                Text("Anonymous").tag("anonymous")
            }
            .pickerStyle(.segmented)
            .disabled(!allowsAnonymousIdentity || isSubmitting)

            Text(identityDescription)
                .font(PirateTokens.Typography.caption)
                .foregroundStyle(colors.textSecondary)
        }
    }

    private var identityDescription: String {
        if effectiveIdentityMode == "anonymous" {
            if anonymousScope == "post_ephemeral" {
                return "A random label will be used for this post only."
            }
            return "A stable anonymous label will be used inside this community."
        }

        return "Posting as \(publicIdentityLabel)."
    }

    private var publicIdentityLabel: String {
        if let label = sessionManager.profile?.globalHandle?.label, !label.isEmpty {
            return "@\(label)"
        }
        if let label = sessionManager.profile?.primaryPublicHandle?.label, !label.isEmpty {
            return "@\(label)"
        }
        if let displayName = sessionManager.profile?.displayName, !displayName.isEmpty {
            return displayName
        }
        return "your public profile"
    }

    private var publishButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView().tint(colors.textOnAccent)
                }
                Text(isSubmitting ? "Posting..." : "Post")
            }
            .font(PirateTokens.Typography.bodyStrong)
            .foregroundStyle(colors.textOnAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.55)
    }

    private enum StatusTone {
        case `default`
        case warning
        case success
    }

    private func statusCard(title: String, message: String, systemImage: String, tone: StatusTone) -> some View {
        let iconColor: Color = {
            switch tone {
            case .default: return colors.textSecondary
            case .warning: return colors.accentWarning
            case .success: return colors.accentSuccess
            }
        }()

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(PirateTokens.Typography.bodyStrong).foregroundStyle(colors.textPrimary)
                Text(message).font(PirateTokens.Typography.caption).foregroundStyle(colors.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.lg))
    }

    private func linkPreviewCard(_ preview: LinkPreviewResponse) -> some View {
        let previewURL = preview.canonicalUrl ?? preview.originalUrl ?? normalizedLinkUrl
        let domain = previewURL.flatMap { URLComponents(string: $0)?.host?.replacingOccurrences(of: "www.", with: "") }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                if let imageUrl = preview.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Rectangle().fill(colors.surfaceSkeleton)
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: radii.md))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(preview.title ?? previewURL ?? "Link preview")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(2)
                    if let domain {
                        Text(domain)
                            .font(PirateTokens.Typography.caption)
                            .foregroundStyle(colors.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
        .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderDefault, lineWidth: 1))
    }

    private func loadComposerContext() async {
        isChecking = true
        errorMessage = nil
        do {
            let preview = try await ApiClient.shared.community(id: communityId)
            let nextEligibility = try await ApiClient.shared.joinEligibility(communityId: communityId)
            communityPreview = preview
            eligibility = nextEligibility
            applyCommunityInvariants(preview.community)
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isChecking = false
    }

    private func joinCommunity() async {
        guard !isJoining else { return }
        isJoining = true
        errorMessage = nil
        do {
            _ = try await ApiClient.shared.joinCommunity(communityId: communityId)
            await loadComposerContext()
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isJoining = false
    }

    private func refreshLinkPreview() async {
        guard postType == .link, let normalizedLinkUrl else {
            linkPreview = nil
            isLoadingLinkPreview = false
            return
        }

        do {
            try await Task.sleep(nanoseconds: 400_000_000)
        } catch {
            return
        }
        if Task.isCancelled { return }

        isLoadingLinkPreview = true
        defer { isLoadingLinkPreview = false }

        do {
            linkPreview = try await ApiClient.shared.linkPreview(communityId: communityId, url: normalizedLinkUrl)
        } catch {
            linkPreview = nil
        }
    }

    private func submit() async {
        guard hasPostingAccess else {
            errorMessage = "Join this community before posting."
            return
        }
        guard canSubmit else { return }

        let linkUrlForRequest: String?
        if postType == .link {
            guard let normalizedLinkUrl else {
                errorMessage = "Enter a valid http or https link."
                return
            }
            linkUrlForRequest = normalizedLinkUrl
        } else {
            linkUrlForRequest = nil
        }

        isSubmitting = true
        errorMessage = nil
        do {
            let identity = effectiveIdentityMode
            let request = CreatePostRequest(
                idempotencyKey: UUID().uuidString,
                title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                body: trimmedBody.isEmpty ? nil : trimmedBody,
                postType: postType.rawValue,
                linkUrl: linkUrlForRequest,
                ageGatePolicy: "none",
                flairId: nil,
                identityMode: identity,
                anonymousScope: identity == "anonymous" ? anonymousScope : nil,
                disclosedQualifierIds: nil,
                translationPolicy: "machine_allowed",
                visibility: resolvedVisibility
            )
            let createdPost = try await ApiClient.shared.createPost(communityId: communityId, body: request)
            publishedDestination = PublishedPostDestination(id: createdPost.id)
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func applyCommunityInvariants(_ community: Community) {
        if community.allowAnonymousIdentity != true {
            identityMode = "public"
        }
        let rules = community.gateRules ?? []
        let allowsPublic = !rules.contains { $0.scope == "viewer" && $0.status == "active" }
        if !allowsPublic {
            audienceVisibility = "members_only"
        }
    }

    private func normalizeHttpUrl(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) != nil { return nil }

        if let parsed = parseHttpUrl(trimmed) {
            return parsed
        }

        let authorityCandidate: String
        if let pathStart = trimmed.firstIndex(where: { "/?#".contains($0) }) {
            authorityCandidate = String(trimmed[..<pathStart])
        } else {
            authorityCandidate = trimmed
        }

        if let colonIndex = authorityCandidate.firstIndex(of: ":"), colonIndex > authorityCandidate.startIndex {
            let hostCandidate = String(authorityCandidate[..<colonIndex]).lowercased()
            let portLikeHost = hostCandidate.contains(".")
                || hostCandidate == "localhost"
                || hostCandidate.hasPrefix("[")
                || matches(hostCandidate, #"^\d{1,3}(?:\.\d{1,3}){3}$"#)
            if !portLikeHost { return nil }
        }

        let lowercased = trimmed.lowercased()
        let schemelessWebUrl = trimmed.contains(".")
            || lowercased.hasPrefix("localhost")
            || matches(trimmed, #"^\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?(?:[/?#]|$)"#)
            || matches(trimmed, #"^\[[\da-f:]+\](?::\d+)?(?:[/?#]|$)"#)

        guard schemelessWebUrl else { return nil }
        return parseHttpUrl("https://\(trimmed)")
    }

    private func parseHttpUrl(_ value: String) -> String? {
        guard
            let components = URLComponents(string: value),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host,
            !host.isEmpty,
            let url = components.url
        else {
            return nil
        }
        return url.absoluteString
    }

    private func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }
}

struct CreateCommunityView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    var sessionManager: SessionManager

    @State private var displayName = ""
    @State private var description = ""
    @State private var membershipMode = "open"
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var created: CommunityCreateAcceptedResponse?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PirateCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Community basics")
                                .font(PirateTokens.Typography.h3)
                                .foregroundStyle(colors.textPrimary)
                            TextField("Name", text: $displayName)
                                .textFieldStyle(.plain)
                                .font(PirateTokens.Typography.body)
                                .foregroundStyle(colors.textPrimary)
                                .padding(12)
                                .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
                            TextEditor(text: $description)
                                .font(PirateTokens.Typography.body)
                                .foregroundStyle(colors.textPrimary)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
                        }
                    }

                    PirateCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Membership")
                                .font(PirateTokens.Typography.h3)
                                .foregroundStyle(colors.textPrimary)
                            Picker("Membership", selection: $membershipMode) {
                                Text("Open").tag("open")
                                Text("Request").tag("request")
                            }
                            .pickerStyle(.segmented)
                            Text(membershipMode == "open" ? "Anyone can join immediately." : "People can request access before posting.")
                                .font(PirateTokens.Typography.caption)
                                .foregroundStyle(colors.textSecondary)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(PirateTokens.Typography.caption)
                            .foregroundStyle(colors.accentDanger)
                    }

                    if let created {
                        PirateCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Community created")
                                    .font(PirateTokens.Typography.h3)
                                    .foregroundStyle(colors.textPrimary)
                                Text("Provisioning: \(created.job?.status ?? "accepted")")
                                    .font(PirateTokens.Typography.caption)
                                    .foregroundStyle(colors.textSecondary)
                                NavigationLink(value: PirateRoute.communityModerationSection(created.community.id, "namespace")) {
                                    Text("Continue to namespace")
                                        .font(PirateTokens.Typography.bodyStrong)
                                        .foregroundStyle(colors.textOnAccent)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                                }
                                .buttonStyle(.plain)
                                NavigationLink(value: PirateRoute.community(created.community.id)) {
                                    Text("Open community")
                                        .font(PirateTokens.Typography.bodyStrong)
                                        .foregroundStyle(colors.accentBrand)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.full))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        Button {
                            Task { await createCommunity() }
                        } label: {
                            HStack {
                                if isSubmitting { ProgressView().tint(colors.textOnAccent) }
                                Text(isSubmitting ? "Creating..." : "Create community")
                            }
                            .font(PirateTokens.Typography.bodyStrong)
                            .foregroundStyle(colors.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                        }
                        .buttonStyle(.plain)
                        .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                        .opacity(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting ? 0.55 : 1)

                        NavigationLink(value: PirateRoute.verificationSelf("community_creation")) {
                            Text("Verify with ID")
                                .font(PirateTokens.Typography.bodyStrong)
                                .foregroundStyle(colors.accentBrand)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.full))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(PirateTokens.pageGutter)
            }
            .background(colors.bgPage)
            .navigationTitle("Create community")
        }
    }

    private func createCommunity() async {
        isSubmitting = true
        errorMessage = nil
        do {
            created = try await ApiClient.shared.createCommunity(CreateCommunityRequest(
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                membershipMode: membershipMode
            ))
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}

struct YourCommunitiesView: View {
    @Environment(\.pirateColors) private var colors
    var sessionManager: SessionManager

    @State private var handle: String?
    @State private var communities: [PublicProfileCommunitySummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let handle {
                        Text("@\(handle)")
                            .font(PirateTokens.Typography.caption)
                            .foregroundStyle(colors.textSecondary)
                            .padding(.horizontal, PirateTokens.pageGutter)
                            .padding(.top, 12)
                    }

                    if isLoading {
                        LoadingView().frame(height: 200)
                    } else if let errorMessage {
                        ErrorView(message: errorMessage, retry: load)
                    } else if communities.isEmpty {
                        EmptyStateView(icon: "person.3", title: "No communities yet", subtitle: "Communities you create will appear here.")
                    } else {
                        ForEach(communities) { community in
                            NavigationLink(value: PirateRoute.community(community.id)) {
                                PirateCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(community.displayName)
                                                .font(PirateTokens.Typography.bodyStrong)
                                                .foregroundStyle(colors.textPrimary)
                                            Text(community.routeSlug.map { "c/\($0)" } ?? community.id)
                                                .font(PirateTokens.Typography.small)
                                                .foregroundStyle(colors.textSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundStyle(colors.textSecondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, PirateTokens.pageGutter)
                        }
                    }
                }
            }
            .background(colors.bgPage)
            .navigationTitle("Your communities")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        guard let handleLabel = sessionManager.profile?.globalHandle?.label else {
            errorMessage = "Public handle unavailable."
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let resolution = try await ApiClient.shared.publicProfile(handle: handleLabel)
            handle = resolution.resolvedHandleLabels?.first ?? handleLabel
            communities = resolution.createdCommunities ?? []
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct UserProfileView: View {
    @Environment(\.pirateColors) private var colors
    let userId: String
    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let profile {
                PirateProfilePage(
                    data: ProfilePageData(
                        profile: profile,
                        viewerContext: .publicProfile,
                        walletAddress: profile.primaryWalletAddress,
                        activityUserId: userId
                    )
                )
            } else if isLoading {
                LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ErrorView(message: errorMessage, retry: load)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(colors.bgPage)
        .navigationTitle(profile?.displayName ?? "Profile")
        .inlineNavigationBarTitle()
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            profile = try await ApiClient.shared.profile(userId: userId)
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct VerificationView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    var sessionManager: SessionManager
    let provider: String
    let intent: String

    @State private var session: VerificationSession?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            VStack(alignment: .leading, spacing: 16) {
                Text(provider == "very" ? "Very verification" : "Self verification")
                    .font(PirateTokens.Typography.h2)
                    .foregroundStyle(colors.textPrimary)
                Text("Intent: \(intent)")
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)

                if let session {
                    PirateCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status: \(session.status ?? "pending")")
                                .font(PirateTokens.Typography.bodyStrong)
                                .foregroundStyle(colors.textPrimary)
                            Text(session.id)
                                .font(PirateTokens.Typography.small)
                                .foregroundStyle(colors.textSecondary)
                                .textSelection(.enabled)
                            if let url = launchURL(from: session), let launchURL = URL(string: url) {
                                Link("Open verification", destination: launchURL)
                                    .font(PirateTokens.Typography.bodyStrong)
                                    .foregroundStyle(colors.textOnAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                            }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.accentDanger)
                }

                Button {
                    Task { await start() }
                } label: {
                    HStack {
                        if isLoading { ProgressView().tint(colors.textOnAccent) }
                        Text(isLoading ? "Starting..." : "Start verification")
                    }
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                Spacer()
            }
            .padding(PirateTokens.pageGutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(colors.bgPage)
            .navigationTitle("Verification")
        }
    }

    private func start() async {
        isLoading = true
        errorMessage = nil
        do {
            session = try await ApiClient.shared.startVerificationSession(sessionRequest: StartVerificationSessionRequest(
                provider: provider,
                providerMode: provider == "self" ? "qr_deeplink" : nil,
                requestedCapabilities: provider == "self" ? ["unique_human"] : nil,
                verificationIntent: intent
            ))
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func launchURL(from session: VerificationSession) -> String? {
        guard let launch = session.launch else { return nil }
        return firstStringValue(named: "verify_url", in: launch)
            ?? firstStringValue(named: "deeplink_callback", in: launch)
            ?? firstStringValue(named: "url", in: launch)
    }

    private func firstStringValue(named key: String, in value: JSONValue) -> String? {
        switch value {
        case .object(let object):
            if let match = object[key]?.stringValue { return match }
            for child in object.values {
                if let match = firstStringValue(named: key, in: child) { return match }
            }
        case .array(let values):
            for child in values {
                if let match = firstStringValue(named: key, in: child) { return match }
            }
        default:
            return nil
        }
        return nil
    }
}

struct CommunityModerationView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    var sessionManager: SessionManager
    let communityId: String
    let section: String?

    @State private var community: Community?
    @State private var namespaceSession: NamespaceVerificationSession?
    @State private var family = "hns"
    @State private var rootLabel = ""
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var message: String?
    @State private var errorMessage: String?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if section == "namespace" {
                        namespaceBody
                    } else {
                        moderationIndex
                    }
                }
                .padding(PirateTokens.pageGutter)
            }
            .background(colors.bgPage)
            .navigationTitle(sectionTitle)
            .inlineNavigationBarTitle()
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var sectionTitle: String {
        section == nil ? "Moderation" : section!.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }

    private var moderationIndex: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(community?.displayName ?? "Community moderation")
                .font(PirateTokens.Typography.h2)
                .foregroundStyle(colors.textPrimary)
            ForEach(PirateRoute.moderationSections.sorted(), id: \.self) { item in
                NavigationLink(value: PirateRoute.communityModerationSection(communityId, item)) {
                    PirateCard {
                        HStack {
                            Text(item.split(separator: "-").map { $0.capitalized }.joined(separator: " "))
                                .font(PirateTokens.Typography.bodyStrong)
                                .foregroundStyle(colors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(colors.textSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var namespaceBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
                LoadingView().frame(height: 180)
            }

            if let message {
                Text(message)
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.accentSuccess)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.accentDanger)
            }

            PirateCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Verify a namespace")
                        .font(PirateTokens.Typography.h3)
                        .foregroundStyle(colors.textPrimary)
                    Picker("Family", selection: $family) {
                        Text("HNS").tag("hns")
                        Text("Spaces").tag("spaces")
                    }
                    .pickerStyle(.segmented)
                    TextField("Root label", text: $rootLabel)
                        .textFieldStyle(.plain)
                        .font(PirateTokens.Typography.body)
                        .foregroundStyle(colors.textPrimary)
                        .padding(12)
                        .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
                    Button {
                        Task { await startNamespaceSession() }
                    } label: {
                        Text(namespaceSession == nil ? "Start verification" : "Start new challenge")
                            .font(PirateTokens.Typography.bodyStrong)
                            .foregroundStyle(colors.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                    }
                    .buttonStyle(.plain)
                    .disabled(rootLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
                }
            }

            if let namespaceSession {
                PirateCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Challenge")
                            .font(PirateTokens.Typography.h3)
                            .foregroundStyle(colors.textPrimary)
                        Text("Status: \(namespaceSession.status ?? "pending")")
                            .font(PirateTokens.Typography.body)
                            .foregroundStyle(colors.textSecondary)
                        challengeValue("Host", namespaceSession.challengeHost)
                        challengeValue("TXT value", namespaceSession.challengeTxtValue)
                        challengeValue("Expires", namespaceSession.challengeExpiresAt)
                        if let failure = namespaceSession.failureReason {
                            Text(failure).foregroundStyle(colors.accentDanger)
                        }
                        Button {
                            Task { await completeNamespaceSession() }
                        } label: {
                            Text(isWorking ? "Checking..." : "Check verification")
                                .font(PirateTokens.Typography.bodyStrong)
                                .foregroundStyle(colors.textOnAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                        }
                        .buttonStyle(.plain)
                        .disabled(isWorking)
                    }
                }
            }

            if community?.namespaceVerificationId != nil {
                NavigationLink(value: PirateRoute.community(communityId)) {
                    Text("Open community")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(colors.accentSuccess, in: RoundedRectangle(cornerRadius: radii.full))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func challengeValue(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            Text(label)
                .font(PirateTokens.Typography.smallStrong)
                .foregroundStyle(colors.textSecondary)
            Text(value)
                .font(PirateTokens.Typography.caption)
                .foregroundStyle(colors.textPrimary)
                .textSelection(.enabled)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await ApiClient.shared.communityDetails(id: communityId)
            community = loaded
            rootLabel = namespaceSession?.submittedRootLabel ?? loaded.routeSlug ?? rootLabel
            if let sessionId = loaded.pendingNamespaceVerificationSessionId {
                namespaceSession = try? await ApiClient.shared.namespaceSession(id: sessionId)
                rootLabel = namespaceSession?.submittedRootLabel ?? rootLabel
                family = namespaceSession?.family ?? family
            }
            message = loaded.namespaceVerificationId != nil ? "Namespace verified." : nil
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func startNamespaceSession() async {
        isWorking = true
        errorMessage = nil
        do {
            let session = try await ApiClient.shared.startNamespaceSession(
                family: family,
                rootLabel: rootLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            namespaceSession = session
            community = try await ApiClient.shared.setPendingNamespaceSession(communityId: communityId, sessionId: session.id)
            message = "Namespace challenge started."
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }

    private func completeNamespaceSession() async {
        guard let namespaceSession else { return }
        isWorking = true
        errorMessage = nil
        do {
            let completed = try await ApiClient.shared.completeNamespaceSession(id: namespaceSession.id)
            self.namespaceSession = completed
            if completed.status == "verified", let namespaceId = completed.namespaceVerificationId {
                community = try await ApiClient.shared.attachNamespace(communityId: communityId, namespaceVerificationId: namespaceId)
            }
            message = completed.status == "verified" ? "Namespace verified." : "Verification status: \(completed.status ?? "pending")."
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
