import SwiftUI
import UniformTypeIdentifiers

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
