import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private struct SubmitCommunityOption: Identifiable {
    let id: String
    let displayName: String
    let routeSlug: String?
    let avatarRef: String?

    var routeLabel: String {
        communityPresentationLabel(
            communityId: id,
            displayName: displayName,
            routeSlug: routeSlug,
            routeSlugImpliesVerified: true
        )
    }

    var routeIsUnverified: Bool {
        !isCommunityRouteVerified(routeSlug: routeSlug, routeSlugImpliesVerified: true)
    }
}

private struct ComposerPickedFile: Identifiable {
    let id = UUID()
    let name: String
    let mimeType: String
    let data: Data
    let sizeBytes: Int
}

private enum ComposerFileImportKind {
    case image
    case video
    case audio
    case songCover
    case liveCover

    var contentTypes: [UTType] {
        switch self {
        case .image, .songCover, .liveCover:
            return [.image]
        case .video:
            return [.movie]
        case .audio:
            return [.audio]
        }
    }

    var fallbackMimeType: String {
        switch self {
        case .image, .songCover, .liveCover:
            return "image/jpeg"
        case .video:
            return "video/mp4"
        case .audio:
            return "audio/mpeg"
        }
    }
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
        self == .text || self == .link || self == .image
    }

    var hasDetailsStep: Bool {
        self == .video || self == .song
    }

    var bodyLabel: String {
        switch self {
        case .link:
            return "Comment"
        case .image, .video, .song:
            return "Caption"
        case .live:
            return "Description"
        case .text:
            return "Body"
        }
    }

    var bodyPlaceholder: String {
        switch self {
        case .text:
            return "Body text (optional)"
        case .link:
            return "Add context (optional)"
        case .image, .video, .song:
            return "Caption (optional)"
        case .live:
            return "Describe the live room"
        }
    }

    var titlePlaceholder: String {
        switch self {
        case .link:
            return "Title (optional)"
        case .song:
            return "Post title"
        case .live:
            return "Live room title"
        default:
            return "Title"
        }
    }

    var fileImportKind: ComposerFileImportKind? {
        switch self {
        case .image:
            return .image
        case .video:
            return .video
        case .song:
            return .audio
        case .text, .link, .live:
            return nil
        }
    }

    var fileButtonLabel: String {
        switch self {
        case .image:
            return "Choose image"
        case .video:
            return "Choose video"
        case .song:
            return "Choose audio"
        default:
            return "Choose file"
        }
    }
}

private enum PostComposerStep: Int, CaseIterable {
    case write
    case details
    case settings
    case preview

    func next(for postType: ComposerPostType) -> PostComposerStep {
        switch self {
        case .write:
            return postType.hasDetailsStep ? .details : .settings
        case .details:
            return .settings
        case .settings:
            return .preview
        case .preview:
            return .preview
        }
    }

    func previous(for postType: ComposerPostType) -> PostComposerStep? {
        switch self {
        case .write:
            return nil
        case .details:
            return .write
        case .settings:
            return postType.hasDetailsStep ? .details : .write
        case .preview:
            return .settings
        }
    }

    var title: String {
        switch self {
        case .write:
            return "Create post"
        case .details:
            return "Post details"
        case .settings:
            return "Post settings"
        case .preview:
            return "Preview post"
        }
    }
}

private func isPrivilegedCommunityStatus(_ status: String?) -> Bool {
    status == "owner" || status == "admin" || status == "moderator"
}

private func hasCommunityPostingAccess(preview: CommunityPreview, eligibility: JoinEligibility?) -> Bool {
    if eligibility?.status == "already_joined" { return true }
    let status = preview.viewerMembershipStatus
    return status == "member" || isPrivilegedCommunityStatus(status)
}

private func hasCommunityMembership(preview: CommunityPreview?, eligibility: JoinEligibility?) -> Bool {
    guard let preview else { return false }
    return hasCommunityPostingAccess(preview: preview, eligibility: eligibility)
}

private func containsAltchaGate(_ summaries: [MembershipGateSummary]?) -> Bool {
    (summaries ?? []).contains { $0.gateType == "altcha_pow" }
}

private extension PostableCommunitySummary {
    func submitOption() -> SubmitCommunityOption? {
        guard action == "compose" || action == "unlock" else { return nil }
        return SubmitCommunityOption(
            id: communityId,
            displayName: displayName,
            routeSlug: routeSlug,
            avatarRef: avatarRef
        )
    }
}

private func makeImage(from data: Data) -> Image? {
    #if os(iOS)
    guard let image = UIImage(data: data) else { return nil }
    return Image(uiImage: image)
    #elseif os(macOS)
    guard let image = NSImage(data: data) else { return nil }
    return Image(nsImage: image)
    #else
    return nil
    #endif
}

private struct PublishedPostDestination: Identifiable, Hashable {
    let id: String
}

struct GlobalSubmitView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.dismiss) private var dismiss
    var sessionManager: SessionManager

    @State private var communities: [SubmitCommunityOption] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if isLoading {
                        LoadingView().frame(height: 180)
                    } else if let errorMessage {
                        ErrorView(message: errorMessage, retry: loadCommunities)
                    } else if communities.isEmpty {
                        EmptyStateView(
                            icon: "person.3",
                            title: "No eligible communities",
                            subtitle: "Join a community before creating a post."
                        )
                    } else {
                        ForEach(communities) { community in
                            NavigationLink(value: PirateRoute.composePost(community.id)) {
                                PirateCard {
                                    HStack(spacing: 12) {
                                        CommunityAvatarView(
                                            avatarRef: community.avatarRef,
                                            communityId: community.id,
                                            displayName: community.displayName,
                                            size: 36
                                        )
                                        CommunityNameLabel(
                                            text: community.routeLabel,
                                            isUnverified: community.routeIsUnverified,
                                            font: PirateTokens.Typography.bodyStrong,
                                            color: colors.textPrimary,
                                            iconSize: 14
                                        )
                                        Spacer()
                                        PirateSystemIconView(systemName: "chevron.right")
                                            .foregroundStyle(colors.textSecondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, PirateTokens.pageGutter)
                        }
                    }
                }
                .padding(.top, 12)
            }
            .background(colors.bgPage)
            .navigationTitle("Communities")
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
            }
            .task { await loadCommunities() }
            .refreshable { await loadCommunities() }
        }
    }

    private func loadCommunities() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            communities = try await loadPostableCommunities()
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPostableCommunities() async throws -> [SubmitCommunityOption] {
        try await ApiClient.shared.postableCommunities()
            .communities
            .compactMap { $0.submitOption() }
    }
}

struct PostComposerView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    @Environment(\.dismiss) private var dismiss
    var sessionManager: SessionManager
    let communityId: String

    @State private var postType = ComposerPostType.text
    @State private var composerStep = PostComposerStep.write
    @State private var title = ""
    @State private var bodyText = ""
    @State private var linkUrl = ""
    @State private var audienceVisibility = "public"
    @State private var identityMode = "public"
    @State private var imageFile: ComposerPickedFile?
    @State private var videoFile: ComposerPickedFile?
    @State private var songFile: ComposerPickedFile?
    @State private var songCoverFile: ComposerPickedFile?
    @State private var liveCoverFile: ComposerPickedFile?
    @State private var songMode = "original"
    @State private var songTitle = ""
    @State private var songGenre = ""
    @State private var songLanguage = ""
    @State private var lyrics = ""
    @State private var geniusAnnotationsUrl = ""
    @State private var videoPosterFrameSeconds = "0"
    @State private var monetizationEnabled = false
    @State private var priceUsd = ""
    @State private var liveRoomKind = "solo"
    @State private var liveAccessMode = "free"
    @State private var liveVisibility = "public"
    @State private var liveScheduleForLater = false
    @State private var liveScheduleAt = ""
    @State private var liveGuestUserId = ""
    @State private var liveSetlistTitle = ""
    @State private var communityPreview: CommunityPreview?
    @State private var eligibility: JoinEligibility?
    @State private var isChecking = true
    @State private var isSubmitting = false
    @State private var isJoining = false
    @State private var isSolvingProofOfWork = false
    @State private var isLoadingLinkPreview = false
    @State private var linkPreview: LinkPreviewResponse?
    @State private var fileImportKind: ComposerFileImportKind?
    @State private var showingFileImporter = false
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

    private var fileImporterContentTypes: [UTType] {
        fileImportKind?.contentTypes ?? [.data]
    }

    private var community: Community? {
        communityPreview?.community
    }

    private var communityDisplayName: String {
        community?.displayName ?? communityId
    }

    private var communityRouteLabel: String {
        communityPresentationLabel(
            communityId: community?.id ?? communityId,
            displayName: communityDisplayName,
            routeSlug: community?.routeSlug,
            namespaceVerificationId: community?.namespaceVerificationId,
            routeSlugImpliesVerified: true
        )
    }

    private var communityRouteIsUnverified: Bool {
        guard let community else { return false }
        return !isCommunityRouteVerified(
            routeSlug: community.routeSlug,
            namespaceVerificationId: community.namespaceVerificationId,
            routeSlugImpliesVerified: true
        )
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
        guard let communityPreview else { return false }
        return hasCommunityPostingAccess(preview: communityPreview, eligibility: eligibility)
    }

    private var postRequiresProofOfWork: Bool {
        !hasCommunityMembership(preview: communityPreview, eligibility: eligibility)
            && containsAltchaGate(communityPreview?.membershipGateSummaries)
    }

    private var hasDraft: Bool {
        switch postType {
        case .text:
            return !trimmedTitle.isEmpty
        case .link:
            return normalizedLinkUrl != nil
        case .image:
            return !trimmedTitle.isEmpty && imageFile != nil
        case .video:
            return !trimmedTitle.isEmpty && videoFile != nil
        case .song:
            return songFile != nil
                && !resolvedSongTitle.isEmpty
                && !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .live:
            return !trimmedTitle.isEmpty
                && !liveSetlistTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var canSubmit: Bool {
        sessionManager.isAuthenticated
            && postType.isNativeSubmitEnabled
            && hasDraft
            && hasPostingAccess
            && !isChecking
            && !isSubmitting
    }

    private var canAdvanceCurrentStep: Bool {
        switch composerStep {
        case .write:
            return canAdvanceWriteStep
        case .details:
            if postType == .song {
                return !resolvedSongTitle.isEmpty
                    && !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        case .settings:
            return true
        case .preview:
            return canSubmit
        }
    }

    private var canAdvanceWriteStep: Bool {
        switch postType {
        case .text:
            return !trimmedTitle.isEmpty
        case .link:
            return normalizedLinkUrl != nil
        case .image:
            return !trimmedTitle.isEmpty && imageFile != nil
        case .video:
            return !trimmedTitle.isEmpty && videoFile != nil
        case .song:
            return songFile != nil
        case .live:
            return !trimmedTitle.isEmpty
        }
    }

    private var resolvedSongTitle: String {
        let explicit = songTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty { return explicit }
        if !trimmedTitle.isEmpty { return trimmedTitle }
        return songFile?.name.replacingOccurrences(of: #"\.[^.]+$"#, with: "", options: .regularExpression) ?? ""
    }

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    communityPill
                    accessStatus
                    stepContent
                }
                .padding(PirateTokens.pageGutter)
            }
            .background(colors.bgPage)
            .navigationTitle(composerStep.title)
            .inlineNavigationBarTitle()
            .safeAreaInset(edge: .bottom) {
                stepFooter
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if let previous = composerStep.previous(for: postType) {
                        Button {
                            composerStep = previous
                        } label: {
                            PirateIconView(icon: .caretLeft, size: 22, color: colors.textPrimary)
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            PirateIconView(icon: .x, size: 22, color: colors.textPrimary)
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }
                }
            }
            .task { await loadComposerContext() }
            .task(id: linkPreviewTaskKey) { await refreshLinkPreview() }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: fileImporterContentTypes,
                allowsMultipleSelection: false,
                onCompletion: handleFileImport
            )
            .navigationDestination(item: $publishedDestination) { destination in
                PostView(sessionManager: sessionManager, postId: destination.id)
            }
        }
    }

    private var communityPill: some View {
        NavigationLink(value: PirateRoute.community(communityId)) {
            HStack(spacing: 12) {
                CommunityAvatarView(
                    avatarRef: community?.avatarRef,
                    communityId: community?.id ?? communityId,
                    displayName: communityDisplayName,
                    size: 28
                )
                CommunityNameLabel(
                    text: communityRouteLabel,
                    isUnverified: communityRouteIsUnverified,
                    font: PirateTokens.Typography.bodyStrong,
                    color: colors.textPrimary,
                    iconSize: 14
                )
                Spacer()
                PirateSystemIconView(systemName: "chevron.right", size: 13)
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
                        if !type.hasDetailsStep && composerStep == .details {
                            composerStep = .write
                        }
                        errorMessage = nil
                    } label: {
                        HStack(spacing: 6) {
                            PirateSystemIconView(systemName: type.icon, size: 14)
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
    private var stepContent: some View {
        switch composerStep {
        case .write:
            writeStep
        case .details:
            detailsStep
        case .settings:
            settingsStep
        case .preview:
            previewStep
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

    private var writeStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            postTypeTabs

            TextField(postType.titlePlaceholder, text: $title)
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

            if let importKind = postType.fileImportKind {
                filePickerSection(kind: importKind)
            }

            if postType == .live {
                liveWriteFields
            }

            Text(postType.bodyLabel)
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
        }
    }

    @ViewBuilder
    private var detailsStep: some View {
        if postType == .video {
            VStack(alignment: .leading, spacing: 14) {
                Text("Video details")
                    .font(PirateTokens.Typography.h3)
                    .foregroundStyle(colors.textPrimary)
                labeledTextField("Poster frame seconds", text: $videoPosterFrameSeconds, placeholder: "0")
                statusCard(
                    title: "Video publishing is next",
                    message: "The native flow can collect and preview video posts. Uploading the video artifact still needs the web asset pipeline on iOS.",
                    systemImage: "video",
                    tone: .warning
                )
            }
        } else if postType == .song {
            VStack(alignment: .leading, spacing: 14) {
                Text("Song details")
                    .font(PirateTokens.Typography.h3)
                    .foregroundStyle(colors.textPrimary)

                Picker("Song mode", selection: $songMode) {
                    Text("Original").tag("original")
                    Text("Remix").tag("remix")
                }
                .pickerStyle(.segmented)

                labeledTextField("Song title", text: $songTitle, placeholder: "Track title")
                labeledTextField("Genre", text: $songGenre, placeholder: "Genre")
                labeledTextField("Language", text: $songLanguage, placeholder: "Primary language")
                labeledTextField("Genius annotations", text: $geniusAnnotationsUrl, placeholder: "https://")

                Text("Lyrics")
                    .font(PirateTokens.Typography.label)
                    .foregroundStyle(colors.textPrimary)
                TextEditor(text: $lyrics)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 160)
                    .padding(8)
                    .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
                    .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderDefault, lineWidth: 1))

                auxiliaryFileButton(label: songCoverFile?.name ?? "Choose cover art", kind: .songCover, systemImage: "photo")
                statusCard(
                    title: "Song publishing is next",
                    message: "The native flow can collect and preview song metadata. Uploading song artifacts still needs the web asset pipeline on iOS.",
                    systemImage: "music.note",
                    tone: .warning
                )
            }
        }
    }

    private var settingsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            audienceSection
            identitySection

            if postType == .song || postType == .video {
                monetizationSection
            }
        }
    }

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            previewCard

            if !postType.isNativeSubmitEnabled {
                statusCard(
                    title: "Preview ready",
                    message: "Native \(postType.label.lowercased()) publishing is not wired in this build yet.",
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

    private func filePickerSection(kind: ComposerFileImportKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                presentFileImporter(kind)
            } label: {
                HStack(spacing: 10) {
                    PirateSystemIconView(systemName: postType.icon, size: 16)
                        .font(.system(size: 16, weight: .semibold))
                    Text(selectedFileLabel(for: postType) ?? postType.fileButtonLabel)
                        .font(PirateTokens.Typography.bodyStrong)
                    Spacer()
                    PirateSystemIconView(systemName: "plus", size: 14)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(colors.textPrimary)
                .padding(12)
                .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
                .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderDefault, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if let file = selectedPickedFile(for: postType) {
                pickedFileCard(file)
            }
        }
    }

    private var liveWriteFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Room kind", selection: $liveRoomKind) {
                Text("Solo").tag("solo")
                Text("Duet").tag("duet")
            }
            .pickerStyle(.segmented)

            if liveRoomKind == "duet" {
                labeledTextField("Guest performer", text: $liveGuestUserId, placeholder: "User id or handle")
            }

            Picker("Access", selection: $liveAccessMode) {
                Text("Free").tag("free")
                Text("Gated").tag("gated")
                Text("Paid").tag("paid")
            }
            .pickerStyle(.segmented)

            Picker("Visibility", selection: $liveVisibility) {
                Text("Public").tag("public")
                Text("Unlisted").tag("unlisted")
            }
            .pickerStyle(.segmented)

            Toggle("Schedule for later", isOn: $liveScheduleForLater)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)

            if liveScheduleForLater {
                labeledTextField("Start time", text: $liveScheduleAt, placeholder: "YYYY-MM-DD HH:MM")
            }

            labeledTextField("Setlist item", text: $liveSetlistTitle, placeholder: "Song or segment title")
            auxiliaryFileButton(label: liveCoverFile?.name ?? "Choose event cover", kind: .liveCover, systemImage: "photo")
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

    private var monetizationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Paid unlock", isOn: $monetizationEnabled)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)

            if monetizationEnabled {
                labeledTextField("Price", text: $priceUsd, placeholder: "1.00")
            }
        }
        .padding(14)
        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.lg))
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

    private var stepFooter: some View {
        VStack(spacing: 10) {
            if let errorMessage {
                Text(errorMessage)
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.accentDanger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                if composerStep == .preview {
                    Task { await submit() }
                } else {
                    composerStep = composerStep.next(for: postType)
                }
            } label: {
                HStack {
                    if isSubmitting || isSolvingProofOfWork {
                        ProgressView().tint(colors.textOnAccent)
                    }
                    Text(footerButtonTitle)
                }
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(colors.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
            }
            .buttonStyle(.plain)
            .disabled(!canAdvanceCurrentStep)
            .opacity(canAdvanceCurrentStep ? 1 : 0.55)
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(colors.bgPage)
    }

    private var footerButtonTitle: String {
        if composerStep != .preview { return "Next" }
        if isSolvingProofOfWork { return "Posting..." }
        if isSubmitting { return "Posting..." }
        return "Post"
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
            PirateSystemIconView(systemName: systemImage, size: 16)
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

    private func labeledTextField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(PirateTokens.Typography.label)
                .foregroundStyle(colors.textPrimary)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)
                .padding(12)
                .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
                .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderDefault, lineWidth: 1))
        }
    }

    private func auxiliaryFileButton(label: String, kind: ComposerFileImportKind, systemImage: String) -> some View {
        Button {
            presentFileImporter(kind)
        } label: {
            HStack(spacing: 10) {
                PirateSystemIconView(systemName: systemImage)
                Text(label)
                Spacer()
                PirateSystemIconView(systemName: "plus")
            }
            .font(PirateTokens.Typography.bodyStrong)
            .foregroundStyle(colors.textPrimary)
            .padding(12)
            .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
            .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderDefault, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func pickedFileCard(_ file: ComposerPickedFile) -> some View {
        HStack(spacing: 12) {
            if postType == .image, let image = makeImage(from: file.data) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: radii.md))
            } else {
                PirateSystemIconView(systemName: postType.icon, size: 18)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(colors.accentBrand)
                    .frame(width: 56, height: 56)
                    .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.md))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
                Text("\(file.mimeType) · \(formattedBytes(file.sizeBytes))")
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.md))
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

    private var previewCard: some View {
        PirateCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    AvatarView(
                        avatarRef: sessionManager.profile?.avatarRef,
                        size: 34,
                        fallbackLabel: publicIdentityLabel,
                        fallbackSeed: sessionManager.profile?.userId
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(effectiveIdentityMode == "anonymous" ? "Anonymous" : publicIdentityLabel)
                            .font(PirateTokens.Typography.bodyStrong)
                            .foregroundStyle(colors.textPrimary)
                        HStack(spacing: 4) {
                            Text(resolvedVisibility == "public" ? "Public ·" : "Members ·")
                                .font(PirateTokens.Typography.small)
                                .foregroundStyle(colors.textSecondary)
                            CommunityNameLabel(
                                text: communityRouteLabel,
                                isUnverified: communityRouteIsUnverified,
                                font: PirateTokens.Typography.small,
                                color: colors.textSecondary,
                                iconSize: 12
                            )
                        }
                    }
                    Spacer()
                }

                if !trimmedTitle.isEmpty {
                    Text(trimmedTitle)
                        .font(PirateTokens.Typography.h3)
                        .foregroundStyle(colors.textPrimary)
                }

                previewContent
            }
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch postType {
        case .text:
            if !trimmedBody.isEmpty {
                Text(trimmedBody)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textPrimary)
            }
        case .link:
            if let linkPreview {
                linkPreviewCard(linkPreview)
            } else {
                Text(normalizedLinkUrl ?? linkUrl)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.accentBrand)
            }
            if !trimmedBody.isEmpty {
                Text(trimmedBody)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textPrimary)
            }
        case .image:
            if let file = imageFile, let image = makeImage(from: file.data) {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: radii.lg))
            }
            if !trimmedBody.isEmpty {
                Text(trimmedBody)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textPrimary)
            }
        case .video:
            mediaPreviewPlaceholder(
                systemImage: "play.rectangle.fill",
                title: videoFile?.name ?? "Video",
                subtitle: monetizationEnabled ? priceLabel : "Free"
            )
        case .song:
            mediaPreviewPlaceholder(
                systemImage: "music.note",
                title: resolvedSongTitle.isEmpty ? "Untitled track" : resolvedSongTitle,
                subtitle: songMode.capitalized
            )
        case .live:
            mediaPreviewPlaceholder(
                systemImage: "antenna.radiowaves.left.and.right",
                title: trimmedTitle.isEmpty ? "Live event" : trimmedTitle,
                subtitle: "\(liveAccessMode.capitalized) · \(liveVisibility.capitalized)"
            )
            if !liveSetlistTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Setlist: \(liveSetlistTitle)")
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)
            }
        }
    }

    private func mediaPreviewPlaceholder(systemImage: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            PirateSystemIconView(systemName: systemImage, size: 24)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(colors.accentBrand)
                .frame(width: 58, height: 58)
                .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.lg))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textPrimary)
                Text(subtitle)
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.lg))
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
            let currentEligibility: JoinEligibility?
            if let eligibility {
                currentEligibility = eligibility
            } else {
                currentEligibility = try? await ApiClient.shared.joinEligibility(communityId: communityId)
            }
            let altchaPayload: String?
            if currentEligibility?.missingCapabilities?.contains("altcha_pow") == true {
                let communityRef = currentEligibility?.communityId.hasPrefix("com_") == true
                    ? (currentEligibility?.communityId ?? communityId)
                    : "com_\(currentEligibility?.communityId ?? communityId)"
                let challenge = try await ApiClient.shared.createAltchaChallenge(
                    scope: "community_join",
                    action: "community:\(communityRef)"
                )
                altchaPayload = try await AltchaSolver.solve(challenge).payload
            } else {
                altchaPayload = nil
            }
            _ = try await ApiClient.shared.joinCommunity(communityId: communityId, altchaPayload: altchaPayload)
            await loadComposerContext()
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isJoining = false
    }

    private func presentFileImporter(_ kind: ComposerFileImportKind) {
        fileImportKind = kind
        showingFileImporter = true
        errorMessage = nil
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first, let kind = fileImportKind else { return }
            Task { await loadPickedFile(url: url, kind: kind) }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func loadPickedFile(url: URL, kind: ComposerFileImportKind) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? kind.fallbackMimeType
            let file = ComposerPickedFile(
                name: url.lastPathComponent,
                mimeType: mimeType,
                data: data,
                sizeBytes: data.count
            )
            switch kind {
            case .image:
                imageFile = file
            case .video:
                videoFile = file
            case .audio:
                songFile = file
                if songTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    songTitle = file.name.replacingOccurrences(of: #"\.[^.]+$"#, with: "", options: .regularExpression)
                }
            case .songCover:
                songCoverFile = file
            case .liveCover:
                liveCoverFile = file
            }
        } catch {
            errorMessage = error.localizedDescription
        }
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
        guard postType.isNativeSubmitEnabled else {
            errorMessage = "Native \(postType.label.lowercased()) publishing is not wired in this build yet."
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
        defer {
            isSubmitting = false
            isSolvingProofOfWork = false
        }

        do {
            let mediaRefs = try await uploadMediaRefsIfNeeded()
            let altchaPayload = try await resolvePostAltchaPayloadIfNeeded()
            let identity = effectiveIdentityMode
            let bodyForRequest = (postType == .text || postType == .link) ? trimmedBody : ""
            let captionForRequest = postType == .image ? trimmedBody : ""
            let request = CreatePostRequest(
                idempotencyKey: UUID().uuidString,
                title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                body: bodyForRequest.isEmpty ? nil : bodyForRequest,
                caption: captionForRequest.isEmpty ? nil : captionForRequest,
                postType: postType.rawValue,
                linkUrl: linkUrlForRequest,
                mediaRefs: mediaRefs,
                ageGatePolicy: "none",
                flairId: nil,
                identityMode: identity,
                anonymousScope: identity == "anonymous" ? anonymousScope : nil,
                disclosedQualifierIds: nil,
                translationPolicy: "machine_allowed",
                visibility: resolvedVisibility
            )
            let createdPost = try await ApiClient.shared.createPost(communityId: communityId, body: request, altchaPayload: altchaPayload)
            publishedDestination = PublishedPostDestination(id: createdPost.id)
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uploadMediaRefsIfNeeded() async throws -> [MediaRef]? {
        guard postType == .image else { return nil }
        guard let imageFile else {
            throw ApiError.serverError(statusCode: 0, message: "Choose an image before posting.", code: nil, retryable: false)
        }
        let uploaded = try await ApiClient.shared.uploadCommunityMedia(
            kind: "post_image",
            data: imageFile.data,
            filename: imageFile.name,
            mimeType: imageFile.mimeType
        )
        return [
            MediaRef(
                storageRef: uploaded.mediaRef,
                mimeType: uploaded.mimeType,
                sizeBytes: uploaded.sizeBytes ?? imageFile.sizeBytes
            )
        ]
    }

    private func resolvePostAltchaPayloadIfNeeded() async throws -> String? {
        guard postRequiresProofOfWork else { return nil }
        isSolvingProofOfWork = true
        let challenge = try await ApiClient.shared.createAltchaChallenge(
            scope: "post_create",
            action: "community:\(communityId)"
        )
        return try await AltchaSolver.solve(challenge).payload
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

    private func selectedPickedFile(for type: ComposerPostType) -> ComposerPickedFile? {
        switch type {
        case .image:
            return imageFile
        case .video:
            return videoFile
        case .song:
            return songFile
        case .text, .link, .live:
            return nil
        }
    }

    private func selectedFileLabel(for type: ComposerPostType) -> String? {
        selectedPickedFile(for: type)?.name
    }

    private func formattedBytes(_ value: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(value))
    }

    private var priceLabel: String {
        let trimmed = priceUsd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Free" }
        return trimmed.hasPrefix("$") ? trimmed : "$\(trimmed)"
    }
}

private enum CreateCommunityStep: Int, CaseIterable {
    case basics = 1
    case access = 2
    case review = 3

    var title: String {
        switch self {
        case .basics: return "Create community"
        case .access: return "Community settings"
        case .review: return "Preview"
        }
    }

    var next: CreateCommunityStep? {
        switch self {
        case .basics: return .access
        case .access: return .review
        case .review: return nil
        }
    }

    var previous: CreateCommunityStep? {
        switch self {
        case .basics: return nil
        case .access: return .basics
        case .review: return .access
        }
    }
}

private enum CreateCommunityMembershipMode: String, CaseIterable, Identifiable {
    case gated
    case request

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gated: return "Automatic after passing gates"
        case .request: return "Approval required"
        }
    }

    var detail: String {
        switch self {
        case .gated:
            return "People can join immediately after passing at least one wallet, identity, or ownership gate."
        case .request:
            return "People request access and moderators approve them."
        }
    }

    var reviewLabel: String {
        switch self {
        case .gated: return "Automatic after passing gates"
        case .request: return "Approval required"
        }
    }
}

private enum CreateCommunityGateMatchMode: String, CaseIterable, Identifiable {
    case all
    case any

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All selected gates"
        case .any: return "Any selected gate"
        }
    }

    var detail: String {
        switch self {
        case .all: return "Members must pass every selected gate."
        case .any: return "Members can pass any one selected gate."
        }
    }
}

private enum CreateCommunityDatabaseRegion: String, CaseIterable, Identifiable {
    case usEast = "aws-us-east-1"
    case usCentral = "aws-us-east-2"
    case usWest = "aws-us-west-2"
    case europe = "aws-eu-west-1"
    case india = "aws-ap-south-1"
    case japan = "aws-ap-northeast-1"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .usEast: return "🇺🇸 US East"
        case .usCentral: return "🇺🇸 US Central"
        case .usWest: return "🇺🇸 US West"
        case .europe: return "🇮🇪 Ireland (EU)"
        case .india: return "🇮🇳 India"
        case .japan: return "🇯🇵 Japan"
        }
    }
}

private enum CreateCommunityAgeGatePolicy: String, CaseIterable, Identifiable {
    case none
    case eighteenPlus = "18_plus"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "All ages"
        case .eighteenPlus: return "18+"
        }
    }
}

private enum CreateCommunityAnonymousScope: String, CaseIterable, Identifiable {
    case communityStable = "community_stable"
    case threadStable = "thread_stable"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .communityStable: return "Community-stable"
        case .threadStable: return "Thread-stable"
        }
    }

    var detail: String {
        switch self {
        case .communityStable:
            return "One persistent anonymous label per user across the entire community."
        case .threadStable:
            return "One persistent anonymous label per user per thread."
        }
    }
}

private enum CreateCommunityGateType: String, CaseIterable, Identifiable {
    case altchaPow = "altcha_pow"
    case uniqueHuman = "unique_human"
    case nationality
    case minimumAge = "minimum_age"
    case gender
    case walletScore = "wallet_score"
    case erc721Holding = "erc721_holding"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .altchaPow: return "Proof-of-work check"
        case .uniqueHuman: return "Palm scan (Very)"
        case .nationality: return "Nationality verification (Self.xyz)"
        case .minimumAge: return "Minimum age (Self.xyz)"
        case .gender: return "Document sex marker (verified ID)"
        case .walletScore: return "Passport score threshold"
        case .erc721Holding: return "Ethereum NFT collection (ERC-721)"
        }
    }

    var section: String {
        switch self {
        case .altchaPow, .uniqueHuman, .nationality, .minimumAge, .gender:
            return "Identity gates"
        case .walletScore, .erc721Holding:
            return "Wallet gates"
        }
    }

    static let reviewOrder: [CreateCommunityGateType] = [
        .altchaPow,
        .uniqueHuman,
        .nationality,
        .minimumAge,
        .gender,
        .walletScore,
        .erc721Holding
    ]

    static let powExclusiveTypes: Set<CreateCommunityGateType> = [
        .uniqueHuman,
        .nationality,
        .minimumAge,
        .gender,
        .walletScore
    ]
}

private enum CreateCommunityGenderMarker: String, CaseIterable, Identifiable {
    case female = "F"
    case male = "M"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .female: return "F marker"
        case .male: return "M marker"
        }
    }
}

private enum CreateCommunityMediaTarget {
    case avatar
    case banner

    var uploadKind: String {
        switch self {
        case .avatar: return "avatar"
        case .banner: return "banner"
        }
    }
}

struct CreateCommunityView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    @Environment(\.navigatePirateRoute) private var navigatePirateRoute
    var sessionManager: SessionManager

    @State private var step: CreateCommunityStep = .basics
    @State private var displayName = ""
    @State private var description = ""
    @State private var databaseRegion: CreateCommunityDatabaseRegion = .usEast
    @State private var membershipMode: CreateCommunityMembershipMode = .gated
    @State private var gateMatchMode: CreateCommunityGateMatchMode = .all
    @State private var selectedGateTypes: Set<CreateCommunityGateType> = [.altchaPow]
    @State private var nationalityCodesText = ""
    @State private var minimumAge = 30
    @State private var genderMarker: CreateCommunityGenderMarker = .female
    @State private var walletScore = 20
    @State private var erc721ContractAddress = ""
    @State private var ageGatePolicy: CreateCommunityAgeGatePolicy = .none
    @State private var allowAnonymousIdentity = true
    @State private var anonymousScope: CreateCommunityAnonymousScope = .communityStable
    @State private var avatarFile: ComposerPickedFile?
    @State private var bannerFile: ComposerPickedFile?
    @State private var showingMediaImporter = false
    @State private var mediaImportTarget: CreateCommunityMediaTarget?
    @State private var showSelfVerification = false
    @State private var pendingCreateAfterVerification = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var created: CommunityCreateAcceptedResponse?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let created {
                        createdContent(created)
                    } else {
                        stepHeader
                        stepContent

                        if let errorMessage {
                            Text(errorMessage)
                                .font(PirateTokens.Typography.caption)
                                .foregroundStyle(colors.accentDanger)
                        }

                        footerActions
                    }
                }
                .padding(PirateTokens.pageGutter)
            }
            .background(colors.bgPage)
            .navigationTitle("Create community")
        }
        .task {
            await sessionManager.refreshUser()
        }
        .sheet(isPresented: $showSelfVerification) {
            SelfVerificationDrawer(
                sessionManager: sessionManager,
                intent: "community_creation",
                requestedCapabilities: ["age_over_18"],
                isPresented: $showSelfVerification,
                onVerified: {
                    await handleAgeVerificationComplete()
                }
            )
        }
        .fileImporter(
            isPresented: $showingMediaImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false,
            onCompletion: handleMediaImport
        )
    }

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var creatorAgeOver18Verified: Bool {
        sessionManager.user?.verificationCapabilities?.ageOver18?.state == "verified"
    }

    private var hasAdultMinimumAgeGate: Bool {
        membershipMode == .gated
            && selectedGateTypes.contains(.minimumAge)
            && minimumAge >= 18
            && minimumAge <= 125
    }

    private var effectiveDefaultAgeGatePolicy: CreateCommunityAgeGatePolicy {
        hasAdultMinimumAgeGate ? .eighteenPlus : ageGatePolicy
    }

    private var creatorAgeVerificationRequired: Bool {
        effectiveDefaultAgeGatePolicy == .eighteenPlus && !creatorAgeOver18Verified
    }

    private var parsedNationalityCodes: [String] {
        nationalityCodesText
            .split { character in
                character == "," || character == " " || character == "\n" || character == "\t"
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
    }

    private var nationalityCodesValid: Bool {
        parsedNationalityCodes.allSatisfy { code in
            code.range(of: "^[A-Z]{2}$", options: .regularExpression) != nil
        }
    }

    private var erc721ContractValid: Bool {
        let trimmed = erc721ContractAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: "^0x[0-9a-fA-F]{40}$", options: .regularExpression) != nil
    }

    private var gateDraftsValid: Bool {
        guard membershipMode == .gated else { return true }
        guard !selectedGateTypes.isEmpty else { return false }
        if selectedGateTypes.contains(.minimumAge), minimumAge < 18 || minimumAge > 125 {
            return false
        }
        if selectedGateTypes.contains(.walletScore), walletScore < 0 || walletScore > 100 {
            return false
        }
        if selectedGateTypes.contains(.erc721Holding), !erc721ContractValid {
            return false
        }
        if selectedGateTypes.contains(.nationality), !nationalityCodesValid {
            return false
        }
        return true
    }

    private var canCreateCommunity: Bool {
        !trimmedDisplayName.isEmpty && gateDraftsValid && !isSubmitting
    }

    private var canContinue: Bool {
        switch step {
        case .basics:
            return !trimmedDisplayName.isEmpty
        case .access:
            return gateDraftsValid
        case .review:
            return canCreateCommunity
        }
    }

    private var stepHeader: some View {
        PirateCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(CreateCommunityStep.allCases, id: \.rawValue) { item in
                        Circle()
                            .fill(item.rawValue <= step.rawValue ? colors.accentBrand : colors.borderDefault)
                            .frame(width: 8, height: 8)
                    }
                    Spacer()
                    Text("Step \(step.rawValue) of \(CreateCommunityStep.allCases.count)")
                        .font(PirateTokens.Typography.smallStrong)
                        .foregroundStyle(colors.textSecondary)
                }
                Text(step.title)
                    .font(PirateTokens.Typography.h2)
                    .foregroundStyle(colors.textPrimary)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .basics:
            basicsStep
        case .access:
            accessStep
        case .review:
            reviewStep
        }
    }

    private var basicsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            PirateCard {
                VStack(alignment: .leading, spacing: 14) {
                    formLabel("Display name")
                    TextField("Community name", text: $displayName)
                        .textFieldStyle(.plain)
                        .font(PirateTokens.Typography.body)
                        .foregroundStyle(colors.textPrimary)
                        .padding(12)
                        .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))

                    formLabel("Description")
                    TextEditor(text: $description)
                        .font(PirateTokens.Typography.body)
                        .foregroundStyle(colors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))

                    formLabel("Data region")
                    Picker("Data region", selection: $databaseRegion) {
                        ForEach(CreateCommunityDatabaseRegion.allCases) { region in
                            Text(region.label).tag(region)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(colors.accentBrand)
                }
            }

            PirateCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Images")
                        .font(PirateTokens.Typography.h3)
                        .foregroundStyle(colors.textPrimary)
                    mediaControl(title: "Avatar", file: avatarFile, target: .avatar)
                    mediaControl(title: "Banner", file: bannerFile, target: .banner)
                }
            }
        }
    }

    private var accessStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            PirateCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Join policy")
                        .font(PirateTokens.Typography.h3)
                        .foregroundStyle(colors.textPrimary)
                    ForEach(CreateCommunityMembershipMode.allCases) { mode in
                        optionButton(
                            title: mode.label,
                            detail: mode.detail,
                            selected: mode == membershipMode
                        ) {
                            setMembershipMode(mode)
                        }
                    }
                }
            }

            if membershipMode == .gated {
                PirateCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gate logic")
                            .font(PirateTokens.Typography.h3)
                            .foregroundStyle(colors.textPrimary)
                        ForEach(CreateCommunityGateMatchMode.allCases) { mode in
                            optionButton(
                                title: mode.label,
                                detail: mode.detail,
                                selected: mode == gateMatchMode
                            ) {
                                gateMatchMode = mode
                            }
                        }
                    }
                }

                PirateCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Identity gates")
                            .font(PirateTokens.Typography.h3)
                            .foregroundStyle(colors.textPrimary)
                        gateToggle(.altchaPow)
                        gateToggle(.uniqueHuman)
                        gateToggle(.nationality)
                        if selectedGateTypes.contains(.nationality) {
                            VStack(alignment: .leading, spacing: 6) {
                                formLabel("Allowed nationalities")
                                TextField("US, CA", text: $nationalityCodesText)
                                    .textFieldStyle(.plain)
                                    .font(PirateTokens.Typography.body)
                                    .foregroundStyle(colors.textPrimary)
                                    .padding(12)
                                    .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
                                if !nationalityCodesValid {
                                    warningText("Select a valid country.")
                                }
                            }
                        }

                        gateToggle(.minimumAge)
                        if selectedGateTypes.contains(.minimumAge) {
                            Stepper(value: $minimumAge, in: 18...125) {
                                Text("Minimum age \(minimumAge)")
                                    .font(PirateTokens.Typography.body)
                                    .foregroundStyle(colors.textPrimary)
                            }
                            .padding(.leading, 4)
                        }

                        gateToggle(.gender)
                        if selectedGateTypes.contains(.gender) {
                            Picker("Document sex marker", selection: $genderMarker) {
                                ForEach(CreateCommunityGenderMarker.allCases) { marker in
                                    Text(marker.label).tag(marker)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                PirateCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Wallet gates")
                            .font(PirateTokens.Typography.h3)
                            .foregroundStyle(colors.textPrimary)
                        gateToggle(.walletScore)
                        if selectedGateTypes.contains(.walletScore) {
                            Stepper(value: $walletScore, in: 0...100) {
                                Text("Minimum score \(walletScore)")
                                    .font(PirateTokens.Typography.body)
                                    .foregroundStyle(colors.textPrimary)
                            }
                            .padding(.leading, 4)
                        }

                        gateToggle(.erc721Holding)
                        if selectedGateTypes.contains(.erc721Holding) {
                            VStack(alignment: .leading, spacing: 6) {
                                formLabel("Collection contract")
                                TextField("0x...", text: $erc721ContractAddress)
                                    .textFieldStyle(.plain)
                                    .font(PirateTokens.Typography.body)
                                    .foregroundStyle(colors.textPrimary)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .padding(12)
                                    .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
                                if !erc721ContractAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !erc721ContractValid {
                                    warningText("Enter a valid Ethereum contract address.")
                                }
                            }
                        }

                        disabledGateRow("Courtyard.io collectibles (Coming soon)")
                    }
                }
            }

            if !hasAdultMinimumAgeGate {
                PirateCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Age restriction")
                            .font(PirateTokens.Typography.h3)
                            .foregroundStyle(colors.textPrimary)
                        Toggle(isOn: Binding(
                            get: { ageGatePolicy == .eighteenPlus },
                            set: { checked in ageGatePolicy = checked ? .eighteenPlus : .none }
                        )) {
                            Text("18+ community")
                                .font(PirateTokens.Typography.bodyStrong)
                                .foregroundStyle(colors.textPrimary)
                        }
                        .tint(colors.accentBrand)

                        if ageGatePolicy == .eighteenPlus && !creatorAgeOver18Verified {
                            warningText("The owner must complete age verification before marking a community for adult content.")
                        }
                    }
                }
            }

            PirateCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Identity and access")
                        .font(PirateTokens.Typography.h3)
                        .foregroundStyle(colors.textPrimary)
                    Toggle(isOn: $allowAnonymousIdentity) {
                        Text("Allow anonymous posting")
                            .font(PirateTokens.Typography.bodyStrong)
                            .foregroundStyle(colors.textPrimary)
                    }
                    .tint(colors.accentBrand)

                    if allowAnonymousIdentity {
                        VStack(alignment: .leading, spacing: 10) {
                            formLabel("Anonymous scope")
                            ForEach(CreateCommunityAnonymousScope.allCases) { scope in
                                optionButton(
                                    title: scope.label,
                                    detail: scope.detail,
                                    selected: scope == anonymousScope
                                ) {
                                    anonymousScope = scope
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var reviewStep: some View {
        PirateCard {
            VStack(alignment: .leading, spacing: 14) {
                reviewRow("Name", trimmedDisplayName)
                reviewRow("Description", trimmedDescription.isEmpty ? "None" : trimmedDescription)
                reviewRow("Data region", databaseRegion.label)
                reviewRow("Membership", membershipMode.reviewLabel)
                reviewRow("Content rating", effectiveDefaultAgeGatePolicy.label)
                if let gateRequirementSummary {
                    reviewRow("Membership gates", gateRequirementSummary)
                }
                reviewRow("Anonymous posting", allowAnonymousIdentity ? "Enabled" : "Disabled")
                if allowAnonymousIdentity {
                    reviewRow("Anonymous scope", anonymousScope.label)
                }
                if let avatarFile {
                    reviewRow("Avatar", avatarFile.name)
                }
                if let bannerFile {
                    reviewRow("Banner", bannerFile.name)
                }
                if creatorAgeVerificationRequired {
                    warningText("This community is marked 18+, so the creator must also pass age verification before launch.")
                }
            }
        }
    }

    private var footerActions: some View {
        HStack(spacing: 12) {
            if let previous = step.previous {
                Button {
                    step = previous
                } label: {
                    Text("Back")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.accentBrand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.full))
                }
                .buttonStyle(.plain)
            }

            if let next = step.next {
                Button {
                    if canContinue {
                        step = next
                    }
                } label: {
                    Text("Continue")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                }
                .buttonStyle(.plain)
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.55)
            } else {
                Button {
                    beginCreateCommunity()
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
                .disabled(!canCreateCommunity)
                .opacity(canCreateCommunity ? 1 : 0.55)
            }
        }
    }

    private func createdContent(_ created: CommunityCreateAcceptedResponse) -> some View {
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
    }

    private func formLabel(_ value: String) -> some View {
        Text(value)
            .font(PirateTokens.Typography.bodyStrong)
            .foregroundStyle(colors.textPrimary)
    }

    private func warningText(_ value: String) -> some View {
        Text(value)
            .font(PirateTokens.Typography.caption)
            .foregroundStyle(colors.accentDanger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.md))
    }

    private func optionButton(
        title: String,
        detail: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(selected ? colors.accentBrand : colors.borderDefault)
                    .frame(width: 12, height: 12)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textPrimary)
                    Text(detail)
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(selected ? colors.surfaceSubtle : colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
            .overlay(
                RoundedRectangle(cornerRadius: radii.md)
                    .stroke(selected ? colors.borderDefault : colors.borderSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func gateToggle(_ type: CreateCommunityGateType) -> some View {
        Toggle(isOn: Binding(
            get: { selectedGateTypes.contains(type) },
            set: { checked in setGate(type, enabled: checked) }
        )) {
            Text(type.title)
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(colors.textPrimary)
        }
        .tint(colors.accentBrand)
        .padding(12)
        .background(selectedGateTypes.contains(type) ? colors.surfaceSubtle : colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
        .overlay(
            RoundedRectangle(cornerRadius: radii.md)
                .stroke(selectedGateTypes.contains(type) ? colors.borderDefault : colors.borderSoft, lineWidth: 1)
        )
    }

    private func disabledGateRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(colors.textSecondary)
            Spacer()
        }
        .padding(12)
        .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
        .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))
        .opacity(0.6)
    }

    private func mediaControl(title: String, file: ComposerPickedFile?, target: CreateCommunityMediaTarget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            formLabel(title)
            HStack(spacing: 12) {
                mediaPreview(file: file, target: target)
                VStack(alignment: .leading, spacing: 6) {
                    Text(file?.name ?? "No file selected")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("PNG, JPG, WebP")
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.textSecondary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 12) {
                Button {
                    mediaImportTarget = target
                    showingMediaImporter = true
                } label: {
                    outlineButtonLabel(file == nil ? "Choose file" : "Replace")
                }
                .buttonStyle(.plain)

                if file != nil {
                    Button {
                        switch target {
                        case .avatar: avatarFile = nil
                        case .banner: bannerFile = nil
                        }
                    } label: {
                        outlineButtonLabel("Remove")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func mediaPreview(file: ComposerPickedFile?, target: CreateCommunityMediaTarget) -> some View {
        ZStack {
            if let file, let image = makeImage(from: file.data) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(colors.bgElevated)
                    .overlay(PirateIconView(icon: .image, filled: true, size: 24, color: colors.textSecondary))
            }
        }
        .frame(width: target == .avatar ? 64 : 96, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: target == .avatar ? radii.full : radii.md))
        .overlay(RoundedRectangle(cornerRadius: target == .avatar ? radii.full : radii.md).stroke(colors.borderSoft, lineWidth: 1))
    }

    private func outlineButtonLabel(_ text: String) -> some View {
        Text(text)
            .font(PirateTokens.Typography.bodyStrong)
            .foregroundStyle(colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.full))
            .overlay(RoundedRectangle(cornerRadius: radii.full).stroke(colors.borderDefault, lineWidth: 1))
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(PirateTokens.Typography.smallStrong)
                .foregroundStyle(colors.textSecondary)
            Text(value)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private var gateRequirementSummary: String? {
        guard membershipMode == .gated else { return nil }
        let values = CreateCommunityGateType.reviewOrder
            .filter { selectedGateTypes.contains($0) }
            .map(gateRequirementLabel)
        return values.isEmpty ? nil : values.joined(separator: ", ")
    }

    private func gateRequirementLabel(for type: CreateCommunityGateType) -> String {
        switch type {
        case .altchaPow:
            return "Proof-of-work check"
        case .uniqueHuman:
            return "Palm scan"
        case .nationality:
            let codes = parsedNationalityCodes
            return codes.isEmpty ? "Nationality verification" : "\(codes.joined(separator: ", ")) nationality"
        case .minimumAge:
            return "\(minimumAge)+ ID check"
        case .gender:
            return "Requires document sex marker \(genderMarker.rawValue)"
        case .walletScore:
            return "Passport Score \(walletScore)+"
        case .erc721Holding:
            let address = erc721ContractAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            return address.isEmpty ? "Ethereum NFT" : "Ethereum NFT from \(shortAddress(address))"
        }
    }

    private func shortAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    private func setMembershipMode(_ mode: CreateCommunityMembershipMode) {
        membershipMode = mode
        if mode == .request {
            selectedGateTypes = []
        } else if selectedGateTypes.isEmpty {
            selectedGateTypes = [.altchaPow]
        }
    }

    private func setGate(_ type: CreateCommunityGateType, enabled: Bool) {
        if enabled {
            if type == .altchaPow {
                selectedGateTypes.subtract(CreateCommunityGateType.powExclusiveTypes)
            } else if CreateCommunityGateType.powExclusiveTypes.contains(type) {
                selectedGateTypes.remove(.altchaPow)
            }
            selectedGateTypes.insert(type)
        } else {
            selectedGateTypes.remove(type)
        }
    }

    private func handleMediaImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first, let target = mediaImportTarget else { return }
            Task { await loadCommunityMedia(url: url, target: target) }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func loadCommunityMedia(url: URL, target: CreateCommunityMediaTarget) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/jpeg"
            let file = ComposerPickedFile(
                name: url.lastPathComponent,
                mimeType: mimeType,
                data: data,
                sizeBytes: data.count
            )
            switch target {
            case .avatar:
                avatarFile = file
            case .banner:
                bannerFile = file
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func beginCreateCommunity() {
        guard canCreateCommunity else { return }
        if creatorAgeVerificationRequired {
            pendingCreateAfterVerification = true
            errorMessage = nil
            showSelfVerification = true
            return
        }
        Task { await createCommunity() }
    }

    private func handleAgeVerificationComplete() async {
        await sessionManager.refreshUser()
        guard !creatorAgeVerificationRequired else {
            errorMessage = "Verify 18+ status before creating an 18+ community."
            pendingCreateAfterVerification = false
            return
        }

        showSelfVerification = false
        if pendingCreateAfterVerification {
            pendingCreateAfterVerification = false
            await createCommunity()
        }
    }

    private func createCommunity() async {
        guard canCreateCommunity else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let avatarRef = try await uploadCommunityMediaIfNeeded(kind: "avatar", file: avatarFile)
            let bannerRef = try await uploadCommunityMediaIfNeeded(kind: "banner", file: bannerFile)
            let result = try await ApiClient.shared.createCommunity(CreateCommunityRequest(
                displayName: trimmedDisplayName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                avatarRef: avatarRef,
                bannerRef: bannerRef,
                databaseRegion: databaseRegion.rawValue,
                membershipMode: membershipMode.rawValue,
                defaultAgeGatePolicy: effectiveDefaultAgeGatePolicy.rawValue,
                allowAnonymousIdentity: allowAnonymousIdentity,
                anonymousIdentityScope: anonymousScope.rawValue,
                gatePolicy: serializedGatePolicy,
                communityBootstrap: Self.defaultBootstrap
            ))
            created = result
            navigatePirateRoute(.community(result.community.id))
        } catch let error as ApiError {
            if error.displayMessage.contains("age_over_18") || error.diagnosticMessage.contains("age_over_18") {
                pendingCreateAfterVerification = true
                showSelfVerification = true
                errorMessage = "Age verification is required to create an 18+ community."
            } else {
                errorMessage = error.displayMessage
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func uploadCommunityMediaIfNeeded(kind: String, file: ComposerPickedFile?) async throws -> String? {
        guard let file else { return nil }
        return try await ApiClient.shared.uploadCommunityMedia(
            kind: kind,
            data: file.data,
            filename: file.name,
            mimeType: file.mimeType
        ).mediaRef
    }

    private var serializedGatePolicy: JSONValue? {
        guard membershipMode == .gated else { return nil }
        let expressions = CreateCommunityGateType.reviewOrder.compactMap { type -> JSONValue? in
            guard selectedGateTypes.contains(type) else { return nil }
            return gateExpression(for: type)
        }
        guard !expressions.isEmpty else { return nil }
        return .object([
            "version": .int(1),
            "expression": .object([
                "op": .string(gateMatchMode == .any ? "or" : "and"),
                "children": .array(expressions)
            ])
        ])
    }

    private func gateExpression(for type: CreateCommunityGateType) -> JSONValue? {
        if type == .uniqueHuman {
            return .object([
                "op": .string("or"),
                "children": .array([
                    .object([
                        "op": .string("gate"),
                        "gate": .object([
                            "type": .string("unique_human"),
                            "provider": .string("self")
                        ])
                    ]),
                    .object([
                        "op": .string("gate"),
                        "gate": .object([
                            "type": .string("unique_human"),
                            "provider": .string("very")
                        ])
                    ])
                ])
            ])
        }
        guard let atom = gateAtom(for: type) else { return nil }
        return .object([
            "op": .string("gate"),
            "gate": atom
        ])
    }

    private func gateAtom(for type: CreateCommunityGateType) -> JSONValue? {
        switch type {
        case .altchaPow:
            return .object(["type": .string("altcha_pow")])
        case .uniqueHuman:
            return nil
        case .nationality:
            return .object([
                "type": .string("nationality"),
                "provider": .string("self"),
                "allowed": .array(parsedNationalityCodes.map { .string($0) })
            ])
        case .minimumAge:
            return .object([
                "type": .string("minimum_age"),
                "provider": .string("self"),
                "minimum_age": .int(minimumAge)
            ])
        case .gender:
            return .object([
                "type": .string("gender"),
                "provider": .string("self"),
                "allowed": .array([.string(genderMarker.rawValue)])
            ])
        case .walletScore:
            return .object([
                "type": .string("wallet_score"),
                "provider": .string("passport"),
                "minimum_score": .int(walletScore)
            ])
        case .erc721Holding:
            return .object([
                "type": .string("erc721_holding"),
                "chain_namespace": .string("eip155:1"),
                "contract_address": .string(erc721ContractAddress.trimmingCharacters(in: .whitespacesAndNewlines))
            ])
        }
    }

    private static let defaultBootstrap = CreateCommunityBootstrapInput(rules: [
        CreateCommunityRuleInput(
            title: "Respect others and be civil",
            body: "No harassment, hate speech, or toxic behavior. Treat all contributors and members with kindness.",
            reportReason: "Respect others and be civil",
            position: 0
        ),
        CreateCommunityRuleInput(
            title: "No spam",
            body: "Excessive promotion, spam, or advertising of any kind is not allowed.",
            reportReason: "No spam",
            position: 1
        )
    ])
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
                                        PirateSystemIconView(systemName: "chevron.right").foregroundStyle(colors.textSecondary)
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

private enum SelfVerificationScreenState {
    case notStarted
    case pending
    case verified
}

struct SelfVerificationView: View {
    var sessionManager: SessionManager
    let intent: String
    var requestedCapabilities: [String] = ["unique_human"]
    var verificationRequirements: [VerificationRequirement] = []
    var onVerified: (() async -> Void)?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            SelfVerificationFlowContent(
                sessionManager: sessionManager,
                intent: intent,
                requestedCapabilities: requestedCapabilities,
                verificationRequirements: verificationRequirements,
                onVerified: onVerified
            )
            .navigationTitle("Verify with ID")
        }
    }
}

struct SelfVerificationDrawer: View {
    var sessionManager: SessionManager
    let intent: String
    var requestedCapabilities: [String] = ["unique_human"]
    var verificationRequirements: [VerificationRequirement] = []
    @Binding var isPresented: Bool
    var onVerified: (() async -> Void)?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            SelfVerificationFlowContent(
                sessionManager: sessionManager,
                intent: intent,
                requestedCapabilities: requestedCapabilities,
                verificationRequirements: verificationRequirements,
                onVerified: onVerified,
                onClose: { isPresented = false }
            )
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }
}

private struct SelfVerificationFlowContent: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    @Environment(\.openURL) private var openURL
    var sessionManager: SessionManager
    let intent: String
    var requestedCapabilities: [String]
    var verificationRequirements: [VerificationRequirement]
    var onVerified: (() async -> Void)?
    var onClose: (() -> Void)?

    @State private var coordinator = VerificationCoordinator.shared
    @State private var session: VerificationSession?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var screenState: SelfVerificationScreenState = .notStarted
    @State private var completingSessionId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(colors.surfaceAccent)
                                .frame(width: 52, height: 52)
                                .overlay(
                                    PirateIconView(icon: .identificationCard, filled: true, size: 26, color: colors.accentBrand)
                                )
                            Text("Verify with ID")
                                .font(PirateTokens.Typography.h2)
                                .foregroundStyle(colors.textPrimary)
                        }
                        Text(descriptionText)
                            .font(PirateTokens.Typography.body)
                            .foregroundStyle(colors.textSecondary)
                    }
                    Spacer()
                    if let onClose {
                        Button {
                            onClose()
                        } label: {
                            PirateIconView(icon: .x, size: 16, color: colors.textSecondary)
                                .frame(width: 34, height: 34)
                                .background(colors.surfaceSubtle, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let errorMessage {
                    statusNote(errorMessage, color: colors.accentDanger)
                }

                VStack(alignment: .leading, spacing: 14) {
                    switch screenState {
                    case .verified:
                        statusNote("Verification complete.", color: colors.accentSuccess)
                    case .pending:
                        statusNote("Complete the Self flow, then return here.", color: colors.textSecondary)
                        Button {
                            Task { await reopenVerification() }
                        } label: {
                            buttonLabel(isLoading ? "Opening..." : "Reopen Self")
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    case .notStarted:
                        Button {
                            Task { await start() }
                        } label: {
                            buttonLabel(isLoading ? "Opening..." : "Open Self")
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    }
                }

                appDownloadSection
            }
            .padding(PirateTokens.pageGutter)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .task {
                await checkExistingVerification()
            }
            .task(id: coordinator.callbackResult) {
                guard let result = coordinator.callbackResult else { return }
                await handleCallback(result)
            }
        }
        .background(colors.bgPage)
    }

    private var descriptionText: String {
        if verificationRequirements.contains(where: { $0.proofType == "nationality" }) {
            return "Self.xyz lets you prove your nationality without sharing your name, photo, or document details with anyone."
        }
        if verificationRequirements.contains(where: { $0.proofType == "minimum_age" }) || requestedCapabilities.contains("age_over_18") {
            return "Self.xyz lets you prove your age without sharing your name, photo, or document details with anyone."
        }
        if requestedCapabilities.contains("gender") {
            return "Self.xyz lets you prove facts from your ID without sharing your name, photo, or document details with anyone."
        }
        return "Self.xyz lets you prove facts like age and nationality without sharing your name, photo, or document details with anyone."
    }

    private func statusNote(_ text: String, color: Color) -> some View {
        Text(text)
            .font(PirateTokens.Typography.body)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.md))
    }

    private var appDownloadSection: some View {
        Link(destination: selfAppStoreURL) {
            outlineButtonLabel("Install Self")
        }
        .buttonStyle(.plain)
    }

    private var selfAppStoreURL: URL {
        URL(string: "https://apps.apple.com/us/app/self-zk-passport-identity/id6478563710")!
    }

    private func buttonLabel(_ title: String) -> some View {
        HStack {
            if isLoading { ProgressView().tint(colors.textOnAccent) }
            Text(title)
        }
        .font(PirateTokens.Typography.bodyStrong)
        .foregroundStyle(colors.textOnAccent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
    }

    private func outlineButtonLabel(_ title: String) -> some View {
        HStack(spacing: 8) {
            PirateIconView(icon: .arrowSquareOut, size: 16, color: colors.textPrimary)
            Text(title)
        }
        .font(PirateTokens.Typography.bodyStrong)
        .foregroundStyle(colors.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.full))
        .overlay(
            RoundedRectangle(cornerRadius: radii.full)
                .stroke(colors.borderDefault, lineWidth: 1)
        )
    }

    private func start() async {
        isLoading = true
        errorMessage = nil
        do {
            let createdSession = try await ApiClient.shared.startVerificationSession(sessionRequest: StartVerificationSessionRequest(
                provider: "self",
                providerMode: "qr_deeplink",
                requestedCapabilities: normalizedRequestedCapabilities,
                verificationRequirements: normalizedVerificationRequirements,
                verificationIntent: intent
            ))
            coordinator.savePendingSession(PendingVerificationSession(
                provider: "self",
                verificationSessionId: createdSession.id
            ))

            guard let callbackURL = VerificationCoordinator.buildCallbackURL(
                verificationSessionId: createdSession.id,
                provider: "self"
            ) else {
                coordinator.clearPendingSession()
                throw SelfVerificationError(message: "Could not build Self callback link.")
            }

            let launchResult = SelfVerificationLaunchBuilder.buildLaunchURL(
                from: createdSession.launch,
                callbackURL: callbackURL
            )
            guard let launchURL = launchResult.url else {
                coordinator.clearPendingSession()
                throw SelfVerificationError(message: "Could not build verification link. Please try again.")
            }

            session = createdSession
            screenState = .pending
            openSelf(launchURL)
        } catch let error as ApiError {
            errorMessage = startErrorMessage(for: error)
        } catch let error as SelfVerificationError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private var normalizedRequestedCapabilities: [String]? {
        let allowed = ["unique_human", "age_over_18", "nationality", "gender"]
        let values = requestedCapabilities.filter { allowed.contains($0) }
        return values.isEmpty && verificationRequirements.isEmpty ? ["unique_human"] : values
    }

    private var normalizedVerificationRequirements: [VerificationRequirement]? {
        verificationRequirements.isEmpty ? nil : verificationRequirements
    }

    private func checkExistingVerification() async {
        guard screenState == .notStarted, !isLoading else { return }
        do {
            let status = try await ApiClient.shared.onboardingStatus()
            if status.uniqueHumanVerificationStatus == "verified" {
                screenState = .verified
            }
        } catch {
            // The verification screen can still start a fresh Self session if status refresh fails.
        }
    }

    private func reopenVerification() async {
        guard let sessionId = session?.id ?? coordinator.readPendingSession()?.verificationSessionId else { return }
        isLoading = true
        errorMessage = nil
        do {
            let refreshedSession = try await ApiClient.shared.verificationSession(id: sessionId)
            coordinator.savePendingSession(PendingVerificationSession(provider: "self", verificationSessionId: sessionId))
            guard let callbackURL = VerificationCoordinator.buildCallbackURL(verificationSessionId: sessionId, provider: "self") else {
                throw SelfVerificationError(message: "Could not build Self callback link.")
            }
            let launchResult = SelfVerificationLaunchBuilder.buildLaunchURL(from: refreshedSession.launch, callbackURL: callbackURL)
            guard let launchURL = launchResult.url else {
                throw SelfVerificationError(message: "Could not build verification link. Please try again.")
            }
            session = refreshedSession
            screenState = .pending
            openSelf(launchURL)
        } catch let error as ApiError {
            errorMessage = startErrorMessage(for: error)
        } catch let error as SelfVerificationError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleCallback(_ result: VerificationCallbackResult) async {
        guard result.provider == "self" else { return }

        switch result {
        case .completed(_, let verificationSessionId, let proof):
            await completeVerification(sessionId: verificationSessionId ?? session?.id, proof: proof)
        case .expired:
            coordinator.clearPendingSession()
            coordinator.clearCallbackResult()
            screenState = .notStarted
            errorMessage = "Verification session expired. Please try again."
        case .failed(_, _, let reason):
            coordinator.clearPendingSession()
            coordinator.clearCallbackResult()
            screenState = .notStarted
            errorMessage = reason
        }
    }

    private func completeVerification(sessionId: String?, proof: String) async {
        guard let sessionId else { return }
        if completingSessionId == sessionId { return }
        completingSessionId = sessionId
        isLoading = true
        errorMessage = nil

        do {
            let completedSession = try await ApiClient.shared.completeVerificationSession(
                id: sessionId,
                request: CompleteVerificationSessionRequest(proof: proof)
            )
            session = completedSession
            coordinator.clearCallbackResult()
            coordinator.clearPendingSession()

            switch completedSession.status {
            case "verified":
                screenState = .verified
                await sessionManager.refreshUser()
                await sessionManager.refreshProfile()
                if let onVerified {
                    await onVerified()
                }
            case "expired":
                screenState = .notStarted
                errorMessage = "Verification session expired. Please try again."
            case "failed":
                screenState = .notStarted
                errorMessage = "Could not complete verification."
            default:
                screenState = .pending
            }
        } catch let error as ApiError {
            completingSessionId = nil
            errorMessage = error.displayMessage
        } catch {
            completingSessionId = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func openSelf(_ url: URL) {
        openURL(url) { accepted in
            if !accepted {
                errorMessage = "Could not open Self. If it is not installed, use Install Self below."
            }
        }
    }

    private func startErrorMessage(for error: ApiError) -> String {
        guard case .serverError(let statusCode, _, let code, _, _) = error else {
            return error.displayMessage
        }
        if code == "provider_unavailable" || statusCode == 501 || statusCode == 502 {
            return "Verification provider is temporarily unavailable. Please try again later."
        }
        if code == "internal_error" || statusCode >= 500 {
            return "Could not start ID verification. Please try again."
        }
        return error.displayMessage
    }
}

private struct SelfVerificationError: Error {
    let message: String
}

struct VerificationView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    @Environment(\.openURL) private var openURL
    var sessionManager: SessionManager
    let provider: String
    let intent: String

    @State private var session: VerificationSession?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Circle()
                        .fill(colors.surfaceAccent)
                        .frame(width: 52, height: 52)
                        .overlay(
                            PirateIconView(
                                icon: provider == "very" ? .handPalm : .checkCircle,
                                filled: true,
                                size: 28,
                                color: colors.textPrimary
                            )
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(provider == "very" ? "Prove you're human" : "Verification")
                            .font(PirateTokens.Typography.h2)
                            .foregroundStyle(colors.textPrimary)
                        Text(provider == "very" ? "Scan your palm with VeryAI to prove you're a unique human." : "Complete verification to continue.")
                            .font(PirateTokens.Typography.caption)
                            .foregroundStyle(colors.textSecondary)
                    }
                }

                if let session {
                    PirateCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(statusTitle(for: session))
                                .font(PirateTokens.Typography.bodyStrong)
                                .foregroundStyle(colors.textPrimary)
                            Text(statusDescription(for: session))
                                .font(PirateTokens.Typography.caption)
                                .foregroundStyle(colors.textSecondary)

                            if launchURL(from: session) != nil {
                                Button {
                                    openLaunchURL(for: session)
                                } label: {
                                    verificationButtonLabel(provider == "very" ? "Open Very" : "Open verification", loading: false)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                Task { await refreshSession() }
                            } label: {
                                verificationOutlineButtonLabel(isLoading ? "Checking..." : "Check status")
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoading)
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
                    verificationButtonLabel(
                        isLoading ? "Starting..." : (provider == "very" ? "Verify" : "Start verification"),
                        loading: isLoading
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                if let download = mobileAppDownload {
                    appDownloadSection(download)
                }

                Spacer()
            }
            .padding(PirateTokens.pageGutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(colors.bgPage)
            .navigationTitle(provider == "very" ? "Palm scan" : "Verification")
        }
    }

    private func start() async {
        if provider == "very" {
            await startVeryNative()
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let createdSession = try await ApiClient.shared.startVerificationSession(sessionRequest: StartVerificationSessionRequest(
                provider: provider,
                providerMode: nil,
                requestedCapabilities: nil,
                verificationIntent: intent
            ))
            session = createdSession
            openLaunchURL(for: createdSession)
        } catch let error as ApiError {
            errorMessage = startErrorMessage(for: error)
            if shouldOpenInstallFallback(for: error) {
                openMobileAppStore()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func startVeryNative() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let result = await VeryVerificationLauncher.launch(verificationIntent: intent)
        session = result.session
        if result.verified {
            await sessionManager.refreshUser()
            await sessionManager.refreshProfile()
        } else {
            errorMessage = result.failureReason ?? "Very verification was not completed."
        }
    }

    private func refreshSession() async {
        guard let id = session?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            let refreshed = try await ApiClient.shared.verificationSession(id: id)
            session = refreshed
            if refreshed.status == "verified" {
                await sessionManager.refreshProfile()
            }
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func openLaunchURL(for session: VerificationSession) {
        guard let rawURL = launchURL(from: session), let url = URL(string: rawURL) else {
            if provider == "very" {
                errorMessage = "Very launch data was not returned yet. Install VeryAI from the App Store, then try again."
                openMobileAppStore()
            }
            return
        }
        openURL(url) { accepted in
            if !accepted {
                if provider == "very" {
                    errorMessage = "Could not open VeryAI. Install it from the App Store, then try again."
                    openMobileAppStore()
                } else {
                    errorMessage = "Could not open verification."
                }
            }
        }
    }

    private func statusTitle(for session: VerificationSession) -> String {
        switch session.status {
        case "verified":
            return "Verified"
        case "failed":
            return "Verification failed"
        case "expired":
            return "Session expired"
        default:
            return provider == "very" ? "Finish your palm scan" : "Verification pending"
        }
    }

    private func statusDescription(for session: VerificationSession) -> String {
        switch session.status {
        case "verified":
            return "You're verified. New onboarding tasks should clear after notifications refresh."
        case "failed":
            return "Start a new verification session and try again."
        case "expired":
            return "This verification session expired. Start a new one to continue."
        default:
            return provider == "very"
                ? "Complete the palm scan, then Pirate will verify the signed result."
                : "Complete the provider flow, then return here and check status."
        }
    }

    private var mobileAppDownload: VerificationMobileAppDownload? {
        switch provider {
        case "very":
            return nil
        case "self":
            return VerificationMobileAppDownload(
                appName: "Self",
                iosURL: URL(string: "https://apps.apple.com/us/app/self-zk-passport-identity/id6478563710")
            )
        default:
            return nil
        }
    }

    private func appDownloadSection(_ download: VerificationMobileAppDownload) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(colors.borderSoft)
                    .frame(height: 1)
                Text("Need the \(download.appName) app?")
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
                Rectangle()
                    .fill(colors.borderSoft)
                    .frame(height: 1)
            }

            if let iosURL = download.iosURL {
                Link(destination: iosURL) {
                    verificationOutlineButtonLabel("App Store")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func startErrorMessage(for error: ApiError) -> String {
        guard provider == "very", shouldOpenInstallFallback(for: error) else {
            return error.displayMessage
        }
        return "We could not start VeryAI from Pirate yet. Install VeryAI from the App Store, then try again."
    }

    private func shouldOpenInstallFallback(for error: ApiError) -> Bool {
        guard provider == "very", !error.isAuthError else { return false }
        guard case .serverError(let statusCode, _, let code, _, _) = error else { return false }
        return code == "internal_error" || code == "provider_unavailable" || statusCode == 501 || statusCode == 502
    }

    private func openMobileAppStore() {
        guard let url = mobileAppDownload?.iosURL else { return }
        openURL(url)
    }

    private func verificationButtonLabel(_ title: String, loading: Bool) -> some View {
        HStack {
            if loading { ProgressView().tint(colors.textOnAccent) }
            Text(title)
        }
        .font(PirateTokens.Typography.bodyStrong)
        .foregroundStyle(colors.textOnAccent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
    }

    private func verificationOutlineButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(PirateTokens.Typography.bodyStrong)
            .foregroundStyle(colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.full))
            .overlay(
                RoundedRectangle(cornerRadius: radii.full)
                    .stroke(colors.borderDefault, lineWidth: 1)
            )
    }

    private func launchURL(from session: VerificationSession) -> String? {
        guard let launch = session.launch else { return nil }
        let keys = provider == "very"
            ? ["deeplink_url", "deeplinkUrl", "deep_link", "deepLink", "app_url", "appUrl", "launch_url", "launchUrl", "universal_link", "universalLink", "url", "href"]
            : ["verify_url", "verifyUrl", "deeplink_callback", "deeplinkCallback", "url", "href"]
        for key in keys {
            if let match = firstStringValue(named: key, in: launch) {
                return match
            }
        }
        return nil
    }

    private func launchMode(from session: VerificationSession) -> String? {
        guard let launch = session.launch else { return nil }
        return firstStringValue(named: "mode", in: launch)
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

private struct VerificationMobileAppDownload {
    let appName: String
    let iosURL: URL?
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
                            PirateSystemIconView(systemName: "chevron.right").foregroundStyle(colors.textSecondary)
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
