#if os(iOS)
import AVFoundation
#endif
import AVKit
import Combine
import SwiftUI

@Observable
final class PirateMediaPlaybackCoordinator {
    var activeMediaID: String?

    func requestPlayback(_ mediaID: String) {
        activeMediaID = mediaID
    }

    func clearPlayback(_ mediaID: String) {
        if activeMediaID == mediaID {
            activeMediaID = nil
        }
    }
}

private struct PirateMediaPlaybackCoordinatorKey: EnvironmentKey {
    static let defaultValue = PirateMediaPlaybackCoordinator()
}

extension EnvironmentValues {
    var pirateMediaPlaybackCoordinator: PirateMediaPlaybackCoordinator {
        get { self[PirateMediaPlaybackCoordinatorKey.self] }
        set { self[PirateMediaPlaybackCoordinatorKey.self] = newValue }
    }
}

struct PiratePostMediaItem: Identifiable {
    enum Kind {
        case image
        case video
    }

    let id: String
    let kind: Kind
    let sourceURL: URL
    let posterURL: URL?
    let title: String?
    let caption: String?
    let aspectRatio: CGFloat?
    let isLinkPreviewFallback: Bool

    var displayAspectRatio: CGFloat {
        aspectRatio ?? (16.0 / 9.0)
    }

    var previewURL: URL {
        posterURL ?? sourceURL
    }

    static func primary(for post: Post) -> PiratePostMediaItem? {
        for (index, media) in (post.mediaRefs ?? []).enumerated() {
            if let item = makeMediaItem(from: media, post: post, index: index) {
                return item
            }
        }

        guard
            let linkImage = post.linkImage,
            let imageURL = ApiClient.shared.publicMediaURL(from: linkImage)
        else {
            return nil
        }

        return PiratePostMediaItem(
            id: "link-preview:\(imageURL.absoluteString)",
            kind: .image,
            sourceURL: imageURL,
            posterURL: nil,
            title: post.linkTitle ?? post.title,
            caption: nil,
            aspectRatio: 16.0 / 9.0,
            isLinkPreviewFallback: true
        )
    }

    private static func makeMediaItem(from media: MediaRef, post: Post, index: Int) -> PiratePostMediaItem? {
        let sourceRef = media.mediaUrl ?? media.storageRef
        let sourceURL = ApiClient.shared.publicMediaURL(from: sourceRef)
        let posterURL = ApiClient.shared.publicMediaURL(from: media.posterRef)
        let kind = resolveKind(media: media, postType: post.postType, sourceRef: sourceRef)
        let title = post.title ?? post.linkTitle

        switch kind {
        case .image:
            guard let sourceURL else { return nil }
            return PiratePostMediaItem(
                id: "media:\(index):\(sourceURL.absoluteString)",
                kind: .image,
                sourceURL: sourceURL,
                posterURL: nil,
                title: title,
                caption: post.caption,
                aspectRatio: aspectRatio(width: media.width, height: media.height),
                isLinkPreviewFallback: false
            )
        case .video:
            guard sourceURL != nil || posterURL != nil else { return nil }
            return PiratePostMediaItem(
                id: "media:\(index):\(sourceURL?.absoluteString ?? posterURL?.absoluteString ?? "")",
                kind: sourceURL == nil ? .image : .video,
                sourceURL: sourceURL ?? posterURL!,
                posterURL: posterURL,
                title: title,
                caption: post.caption,
                aspectRatio: aspectRatio(
                    width: media.posterWidth ?? media.width,
                    height: media.posterHeight ?? media.height
                ),
                isLinkPreviewFallback: false
            )
        case nil:
            return nil
        }
    }

    private static func resolveKind(media: MediaRef, postType: String?, sourceRef: String?) -> Kind? {
        let hints = [media.mimeType, media.mediaType, postType]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        if hints.contains(where: { $0.hasPrefix("image/") || $0 == "image" }) {
            return .image
        }
        if hints.contains(where: { $0.hasPrefix("video/") || $0 == "video" }) {
            return .video
        }

        if let extensionHint = fileExtension(in: sourceRef) {
            if imageExtensions.contains(extensionHint) { return .image }
            if videoExtensions.contains(extensionHint) { return .video }
        }

        if media.posterRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return .video
        }

        return nil
    }

    private static func aspectRatio(width: Int?, height: Int?) -> CGFloat? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        let ratio = CGFloat(width) / CGFloat(height)
        guard ratio.isFinite, ratio > 0 else { return nil }
        return ratio
    }

    private static func fileExtension(in value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let withoutQuery = value.split(separator: "?", maxSplits: 1).first ?? Substring(value)
        let withoutFragment = withoutQuery.split(separator: "#", maxSplits: 1).first ?? withoutQuery
        guard let last = withoutFragment.split(separator: ".").last else { return nil }
        return String(last).lowercased()
    }

    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif"]
    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "webm", "m3u8"]
}

struct PostMediaView: View {
    enum Context {
        case feed
        case detail

        var maxHeight: CGFloat {
            switch self {
            case .feed: return 420
            case .detail: return 640
            }
        }

        var isDetail: Bool {
            self == .detail
        }
    }

    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii

    let post: Post
    let context: Context

    init(post: Post, context: Context = .feed) {
        self.post = post
        self.context = context
    }

    var body: some View {
        if let item = PiratePostMediaItem.primary(for: post) {
            mediaContent(item)
                .frame(maxWidth: .infinity)
                .background(colors.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: radii.md))
                .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))
        }
    }

    @ViewBuilder
    private func mediaContent(_ item: PiratePostMediaItem) -> some View {
        switch item.kind {
        case .image:
            imageContent(url: item.sourceURL, title: item.title, aspectRatio: item.displayAspectRatio)
        case .video:
            videoContent(item)
        }
    }

    private func imageContent(url: URL, title: String?, aspectRatio: CGFloat) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            case .failure:
                unavailableState(systemName: "photo")
            case .empty:
                loadingState
            @unknown default:
                loadingState
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .frame(maxHeight: context.maxHeight)
        .accessibilityLabel(title ?? "Post media")
    }

    @ViewBuilder
    private func videoContent(_ item: PiratePostMediaItem) -> some View {
        if context.isDetail {
            DetailVideoMediaView(item: item, maxHeight: context.maxHeight)
        } else if let posterURL = item.posterURL {
            ZStack {
                imageContent(url: posterURL, title: item.title, aspectRatio: item.displayAspectRatio)
                playBadge
            }
        } else {
            PirateVideoPlayer(url: item.sourceURL, muted: true, autoplay: true, playbackID: "video:\(item.id)")
                .aspectRatio(item.displayAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: context.maxHeight)
                .allowsHitTesting(false)
        }
    }

    private var loadingState: some View {
        ZStack {
            colors.bgElevated
            ProgressView()
                .tint(colors.accentBrand)
        }
    }

    private func unavailableState(systemName: String) -> some View {
        ZStack {
            colors.bgElevated
            PirateSystemIconView(systemName: systemName, size: 28)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(colors.textSecondary)
        }
    }

    private var playBadge: some View {
        PirateSystemIconView(systemName: "play.fill", size: 18)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(colors.textOnAccent)
            .frame(width: 48, height: 48)
            .background(colors.bgOverlay, in: Circle())
            .accessibilityHidden(true)
    }
}

private struct DetailVideoMediaView: View {
    @Environment(\.pirateColors) private var colors

    let item: PiratePostMediaItem
    let maxHeight: CGFloat

    @State private var isPlaying = false

    var body: some View {
        if !isPlaying, let posterURL = item.posterURL {
            Button {
                isPlaying = true
            } label: {
                ZStack {
                    AsyncImage(url: posterURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                        case .failure:
                            colors.bgElevated
                        case .empty:
                            ZStack {
                                colors.bgElevated
                                ProgressView()
                                    .tint(colors.accentBrand)
                            }
                        @unknown default:
                            colors.bgElevated
                        }
                    }
                    .aspectRatio(item.displayAspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: maxHeight)

                    PirateSystemIconView(systemName: "play.fill", size: 22)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(colors.textOnAccent)
                        .frame(width: 58, height: 58)
                        .background(colors.bgOverlay, in: Circle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.title.map { "Play \($0)" } ?? "Play video")
        } else {
            PirateVideoPlayer(url: item.sourceURL, muted: false, autoplay: isPlaying, playbackID: "video:\(item.id)")
                .aspectRatio(item.displayAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: maxHeight)
        }
    }
}

private struct PirateVideoPlayer: View {
    @Environment(\.pirateMediaPlaybackCoordinator) private var playbackCoordinator

    let url: URL
    let muted: Bool
    let autoplay: Bool
    let playbackID: String

    @State private var player = AVPlayer()
    @State private var loadedURL: URL?

    var body: some View {
        VideoPlayer(player: player)
            .background(Color.black)
            .onAppear(perform: configurePlayer)
            .onChange(of: url) { _, _ in
                configurePlayer()
            }
            .onChange(of: playbackCoordinator.activeMediaID) { _, activeMediaID in
                guard !muted else { return }
                if activeMediaID != playbackID {
                    player.pause()
                } else if autoplay {
                    player.play()
                }
            }
            .onDisappear {
                player.pause()
                playbackCoordinator.clearPlayback(playbackID)
            }
    }

    private func configurePlayer() {
        if loadedURL != url {
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            loadedURL = url
        }
        player.isMuted = muted
        if autoplay {
            if !muted {
                configureAudioSession()
                playbackCoordinator.requestPlayback(playbackID)
            }
            player.play()
        }
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("[PirateVideoPlayer] audio session setup failed: \(error)")
            #endif
        }
        #endif
    }
}

struct SongPostCommerceState {
    let listing: CommunityListing?
    let purchase: CommunityPurchase?
    let currentUserId: String?

    static let none = SongPostCommerceState(listing: nil, purchase: nil, currentUserId: nil)
}

struct SongPostView: View {
    enum Context {
        case feed
        case detail
    }

    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii

    let localizedPost: LocalizedPostResponse
    let context: Context
    let commerce: SongPostCommerceState
    let isLoadingCommerce: Bool
    let commerceError: String?
    let purchaseMessage: String?
    let onBuy: (() -> Void)?
    let onSignIn: (() -> Void)?

    init(
        localizedPost: LocalizedPostResponse,
        context: Context = .feed,
        commerce: SongPostCommerceState = .none,
        isLoadingCommerce: Bool = false,
        commerceError: String? = nil,
        purchaseMessage: String? = nil,
        onBuy: (() -> Void)? = nil,
        onSignIn: (() -> Void)? = nil
    ) {
        self.localizedPost = localizedPost
        self.context = context
        self.commerce = commerce
        self.isLoadingCommerce = isLoadingCommerce
        self.commerceError = commerceError
        self.purchaseMessage = purchaseMessage
        self.onBuy = onBuy
        self.onSignIn = onSignIn
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            mainRow

            if ui.showOwned {
                statusPill(icon: "checkmark", label: "Unlocked", color: colors.accentSuccess, background: colors.surfaceSuccess)
            }

            if ui.isAgeGated && ui.ageGateRequiresProof {
                gatedAction
            } else if ui.showPrice || ui.showUnlock {
                purchaseRow
            }

            if let derivative = derivativeSummary {
                Text(derivative)
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
            }

            if let annotationsURL {
                Link(destination: annotationsURL) {
                    HStack(spacing: 6) {
                        Text("View on Genius")
                            .lineLimit(1)
                        PirateSystemIconView(systemName: "arrow.up.right", size: 11)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(PirateTokens.Typography.smallStrong)
                    .foregroundStyle(colors.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(colors.bgPage.opacity(0.45), in: RoundedRectangle(cornerRadius: radii.full))
                    .overlay(RoundedRectangle(cornerRadius: radii.full).stroke(colors.borderSoft, lineWidth: 1))
                }
            }

            if context == .detail, let caption = localizedPost.translatedCaption ?? post.caption, !caption.isEmpty {
                Text(caption)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textSecondary)
            }

            if let purchaseMessage {
                Text(purchaseMessage)
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.textSecondary)
            } else if let commerceError {
                Text(commerceError)
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.accentDanger)
            }
        }
        .padding(context == .detail ? 12 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
        .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }

    private var mainRow: some View {
        HStack(alignment: .center, spacing: 12) {
            artwork
                .frame(width: artworkSize, height: artworkSize)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(songTitle)
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)

                    if let duration = durationLabel, !ui.isAgeGated {
                        Text("(\(duration))")
                            .font(PirateTokens.Typography.small)
                            .foregroundStyle(colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                if let artistLabel, !artistLabel.isEmpty, artistLabel != songTitle {
                    Text(artistLabel)
                        .font(PirateTokens.Typography.small)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                }

                if ui.canShowPreview {
                    Text("Preview")
                        .font(PirateTokens.Typography.smallStrong)
                        .foregroundStyle(colors.accentBrand)
                        .lineLimit(1)
                } else if post.accessMode == "locked", !ui.showOwned {
                    Text("Locked")
                        .font(PirateTokens.Typography.smallStrong)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            SongPlaybackButton(
                source: playbackSource,
                action: ui.primaryAction,
                title: songTitle,
                durationMs: playbackDurationMs
            )
        }
    }

    private var artwork: some View {
        ZStack {
            colors.surfaceSubtle

            if let artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: ui.showAgeGatedArtwork ? 8 : 0)
                            .saturation(ui.showAgeGatedArtwork ? 0 : 1)
                    case .failure:
                        fallbackArtworkIcon
                    case .empty:
                        ProgressView().tint(colors.accentBrand)
                    @unknown default:
                        fallbackArtworkIcon
                    }
                }
            } else {
                fallbackArtworkIcon
            }

            if ui.showAgeGatedArtwork {
                colors.bgOverlay
                PirateSystemIconView(systemName: "lock.fill", size: 20)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(colors.textOnAccent)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radii.md))
        .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))
    }

    private var fallbackArtworkIcon: some View {
        PirateSystemIconView(systemName: "music.note", size: 22)
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(colors.textSecondary)
    }

    private var purchaseRow: some View {
        HStack(spacing: 10) {
            Text(purchasePrompt)
                .font(PirateTokens.Typography.small)
                .foregroundStyle(colors.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                if onBuy != nil {
                    onBuy?()
                } else {
                    onSignIn?()
                }
            } label: {
                HStack(spacing: 6) {
                    if isLoadingCommerce {
                        ProgressView()
                            .tint(colors.textOnAccent)
                            .scaleEffect(0.75)
                    }
                    Text(buyButtonTitle)
                        .font(PirateTokens.Typography.smallStrong)
                        .lineLimit(1)
                }
                .foregroundStyle(colors.textOnAccent)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
            }
            .buttonStyle(.plain)
            .disabled(isLoadingCommerce || (onBuy == nil && onSignIn == nil))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
        .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))
    }

    private var gatedAction: some View {
        HStack(spacing: 10) {
            Text("Prove you're 18+ to listen")
                .font(PirateTokens.Typography.small)
                .foregroundStyle(colors.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onSignIn?()
            } label: {
                Text("Verify Age")
                    .font(PirateTokens.Typography.smallStrong)
                    .foregroundStyle(colors.textOnAccent)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
        .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))
    }

    private func statusPill(icon: String, label: String, color: Color, background: Color) -> some View {
        HStack(spacing: 6) {
            PirateSystemIconView(systemName: icon, size: 12)
                .font(.system(size: 12, weight: .bold))
            Text(label)
                .font(PirateTokens.Typography.smallStrong)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(background, in: RoundedRectangle(cornerRadius: radii.full))
    }

    private var post: Post { localizedPost.post }

    private var ui: DerivedSongUI {
        DerivedSongUI(
            playbackSource: playbackSource,
            post: post,
            listing: commerce.listing,
            purchase: commerce.purchase,
            viewerIsAuthor: viewerOwnsPost,
            ageGateViewerState: localizedPost.ageGateViewerState
        )
    }

    private var songTitle: String {
        firstNonEmpty(localizedPost.songPresentation?.title, post.songTitle, localizedPost.translatedTitle, post.title) ?? "Untitled song"
    }

    private var artistLabel: String? {
        post.authorAnonymousLabel ?? post.authorDisplayName
    }

    private var artworkURL: URL? {
        ApiClient.shared.publicMediaURL(from: localizedPost.songPresentation?.coverArtRef)
            ?? ApiClient.shared.publicMediaURL(from: post.mediaRefs?.first?.posterRef)
    }

    private var annotationsURL: URL? {
        guard let value = post.songAnnotationsURL?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return URL(string: value)
    }

    private var durationLabel: String? {
        guard let durationMs = playbackDurationMs else { return nil }
        let totalSeconds = max(0, durationMs / 1000)
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var playbackDurationMs: Int? {
        let durationMs = localizedPost.songPresentation?.durationMs ?? post.mediaRefs?.first?.durationMs
        guard let durationMs, durationMs > 0 else { return nil }
        return durationMs
    }

    private var derivativeSummary: String? {
        guard post.songMode == "remix", let refs = post.upstreamAssetRefs, !refs.isEmpty else { return nil }
        return refs.count == 1 ? "Derived from Source 1" : "Derived from Source 1 +\(refs.count - 1)"
    }

    private var playbackSource: SongPlaybackSource? {
        if post.accessMode == "locked", hasFullSongAccess, let communityId = post.communityId, let assetId = post.asset {
            return SongPlaybackSource(
                key: "asset:\(assetId)",
                url: ApiClient.shared.communityAssetContentURL(communityId: communityId, assetId: assetId),
                headers: ApiClient.shared.authorizationHeaders()
            )
        }

        guard let media = post.mediaRefs?.first else { return nil }
        guard let sourceURL = ApiClient.shared.publicMediaURL(from: media.mediaUrl ?? media.storageRef) else { return nil }
        return SongPlaybackSource(key: "preview:\(post.id)", url: sourceURL, headers: nil)
    }

    private var viewerOwnsPost: Bool {
        localizedPost.viewerIsAuthor == true || commerce.currentUserId == post.authorUserId
    }

    private var hasFullSongAccess: Bool {
        post.accessMode != "locked" || viewerOwnsPost || commerce.purchase != nil
    }

    private var purchasePrompt: String {
        if priceLabel != nil {
            return ui.canShowPreview ? "Preview is available. Unlock the full song." : "Unlock the full song."
        }
        return ui.canShowPreview ? "Preview is available. Full playback requires unlock." : "Full playback requires unlock."
    }

    private var buyButtonTitle: String {
        if isLoadingCommerce { return "Loading" }
        if let priceLabel { return "Buy \(priceLabel)" }
        return "Unlock"
    }

    private var priceLabel: String? {
        guard let cents = commerce.listing?.priceCents else { return nil }
        return Self.usdFormatter.string(from: NSNumber(value: Double(cents) / 100.0))
    }

    private var artworkSize: CGFloat {
        context == .detail ? 86 : 74
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    private static let usdFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

private struct DerivedSongUI {
    let isPlayable: Bool
    let canShowPreview: Bool
    let isAgeGated: Bool
    let ageGateRequiresProof: Bool
    let showAgeGatedArtwork: Bool
    let showPrice: Bool
    let showUnlock: Bool
    let showOwned: Bool
    let primaryAction: SongPlaybackButton.Action
    let hasFullAccess: Bool

    init(
        playbackSource: SongPlaybackSource?,
        post: Post,
        listing: CommunityListing?,
        purchase: CommunityPurchase?,
        viewerIsAuthor: Bool,
        ageGateViewerState: String?
    ) {
        let isLocked = post.accessMode == "locked"
        let isListed = listing != nil
        let isListingActive = listing?.status == "active"
        let isOwned = !isLocked || viewerIsAuthor || purchase != nil
        let isAdult = post.ageGatePolicy == "18_plus" && post.contentSafetyState == "adult"
        let requiresProof = isAdult && ageGateViewerState != "verified_allowed"
        let canPreview = isLocked && !isOwned && playbackSource != nil && !requiresProof

        self.isPlayable = !requiresProof && playbackSource != nil
        self.canShowPreview = canPreview
        self.isAgeGated = isAdult
        self.ageGateRequiresProof = requiresProof
        self.showAgeGatedArtwork = isAdult
        self.showPrice = isLocked && !isOwned && isListed && isListingActive
        self.showUnlock = isLocked && !isOwned && (!isListed || !isListingActive)
        self.showOwned = isLocked && isOwned
        self.hasFullAccess = isOwned

        if requiresProof || playbackSource == nil {
            self.primaryAction = .locked
        } else if canPreview {
            self.primaryAction = .preview
        } else {
            self.primaryAction = .play
        }
    }
}

private struct SongPlaybackSource: Equatable {
    let key: String
    let url: URL
    let headers: [String: String]?
}

private struct SongPlaybackButton: View {
    @Environment(\.pirateMediaPlaybackCoordinator) private var playbackCoordinator

    enum Action {
        case play
        case preview
        case locked
    }

    @Environment(\.pirateColors) private var colors

    let source: SongPlaybackSource?
    let action: Action
    let title: String
    let durationMs: Int?

    @State private var player = AVPlayer()
    @State private var loadedSource: SongPlaybackSource?
    @State private var currentItem: AVPlayerItem?
    @State private var timeObserverToken: Any?
    @State private var progressFraction = 0.0
    @State private var state: PlaybackState = .idle

    private enum PlaybackState {
        case idle
        case buffering
        case playing
        case paused
    }

    var body: some View {
        Button {
            togglePlayback()
        } label: {
            ZStack {
                Circle()
                    .fill(action == .locked ? colors.surfaceDisabled : colors.accentBrand)

                progressRing

                switch buttonIcon {
                case .progress:
                    ProgressView()
                        .tint(colors.textOnAccent)
                        .scaleEffect(0.85)
                case .system(let name):
                    PirateSystemIconView(systemName: name, size: 17)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(colors.textOnAccent)
                        .offset(x: name == "play.fill" ? 1 : 0)
                }
            }
            .frame(width: 46, height: 46)
        }
        .buttonStyle(.plain)
        .disabled(action == .locked || source == nil)
        .accessibilityLabel(accessibilityLabel)
        .onDisappear {
            player.pause()
            resetPlayback()
        }
        .onChange(of: source) { oldSource, _ in
            if source != loadedSource {
                resetPlayback(clearing: oldSource?.key)
            }
        }
        .onChange(of: playbackCoordinator.activeMediaID) { _, activeMediaID in
            guard activeMediaID != playbackID else { return }
            if state == .playing || state == .buffering {
                player.pause()
                state = .paused
            }
        }
        .onReceive(player.publisher(for: \.timeControlStatus)) { status in
            guard playbackCoordinator.activeMediaID == playbackID else { return }
            switch status {
            case .playing:
                state = .playing
            case .waitingToPlayAtSpecifiedRate:
                state = .buffering
            case .paused:
                if currentItem?.status == .failed {
                    resetPlayback()
                    return
                }
                if state == .playing || state == .buffering {
                    state = .paused
                }
            @unknown default:
                break
            }
        }
    }

    private enum ButtonIcon {
        case progress
        case system(String)
    }

    private var buttonIcon: ButtonIcon {
        if state == .buffering { return .progress }
        if state == .playing { return .system("pause.fill") }
        if action == .locked { return .system("lock.fill") }
        return .system("play.fill")
    }

    private var progressRing: some View {
        ZStack {
            if durationMs != nil || progressFraction > 0 {
                Circle()
                    .stroke(colors.textOnAccent.opacity(0.22), lineWidth: 2)
            }

            if progressFraction > 0 {
                Circle()
                    .trim(from: 0, to: progressFraction)
                    .stroke(
                        colors.textOnAccent,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
        .padding(2)
        .accessibilityHidden(true)
    }

    private var accessibilityLabel: String {
        switch action {
        case .locked: return "\(title) is locked"
        case .preview: return "Play preview"
        case .play: return state == .playing ? "Pause \(title)" : "Play \(title)"
        }
    }

    private func togglePlayback() {
        guard let source else { return }
        if state == .playing || state == .buffering {
            player.pause()
            playbackCoordinator.clearPlayback(playbackID)
            state = .paused
            return
        }

        configureAudioSession()
        playbackCoordinator.requestPlayback(playbackID)

        if loadedSource != source {
            let asset: AVURLAsset
            if let headers = source.headers, !headers.isEmpty {
                asset = AVURLAsset(url: source.url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            } else {
                asset = AVURLAsset(url: source.url)
            }
            let item = AVPlayerItem(asset: asset)
            currentItem = item
            player.replaceCurrentItem(with: item)
            installProgressObserver()
            loadedSource = source
        }

        state = .buffering
        player.play()
    }

    private var playbackID: String {
        source?.key ?? "song:\(title)"
    }

    private func resetPlayback(clearing mediaID: String? = nil) {
        player.pause()
        player.replaceCurrentItem(with: nil)
        removeProgressObserver()
        currentItem = nil
        loadedSource = nil
        progressFraction = 0
        state = .idle
        playbackCoordinator.clearPlayback(mediaID ?? playbackID)
    }

    private func installProgressObserver() {
        removeProgressObserver()
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { time in
            updateProgress(elapsedSeconds: time.seconds)
        }
    }

    private func removeProgressObserver() {
        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }

    private func updateProgress(elapsedSeconds: Double) {
        guard elapsedSeconds.isFinite, elapsedSeconds >= 0 else {
            progressFraction = 0
            return
        }

        let durationSeconds: Double?
        if let durationMs {
            durationSeconds = Double(durationMs) / 1000
        } else if let itemDuration = currentItem?.duration.seconds, itemDuration.isFinite, itemDuration > 0 {
            durationSeconds = itemDuration
        } else {
            durationSeconds = nil
        }

        guard let durationSeconds, durationSeconds > 0 else {
            progressFraction = 0
            return
        }

        progressFraction = min(1, max(0, elapsedSeconds / durationSeconds))
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            #if DEBUG
            print("[SongPlaybackButton] audio session setup failed: \(error)")
            #endif
        }
        #endif
    }
}

struct PostLinkPreview: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii

    let post: Post
    let compact: Bool
    let showsPreviewImage: Bool

    init(post: Post, compact: Bool = true, showsPreviewImage: Bool = true) {
        self.post = post
        self.compact = compact
        self.showsPreviewImage = showsPreviewImage
    }

    static func canRender(post: Post, showsPreviewImage: Bool = true) -> Bool {
        hasText(post.linkUrl)
            || hasText(post.linkTitle)
            || hasText(post.linkDescription)
            || (showsPreviewImage && hasText(post.linkImage))
    }

    var body: some View {
        if let linkURL = resolvedLinkURL {
            Link(destination: linkURL) {
                previewContent(sourceLabel: sourceLabel(for: linkURL), titleFallback: linkURL.absoluteString)
            }
        } else if Self.canRender(post: post, showsPreviewImage: showsPreviewImage) {
            previewContent(sourceLabel: nil, titleFallback: "Link")
        }
    }

    private var resolvedLinkURL: URL? {
        guard let linkUrl = post.linkUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !linkUrl.isEmpty else {
            return nil
        }
        return URL(string: linkUrl)
    }

    private var previewImageSize: CGFloat {
        compact ? 76 : 104
    }

    private func previewContent(sourceLabel: String?, titleFallback: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                if let sourceLabel {
                    HStack(spacing: 6) {
                        PirateSystemIconView(systemName: "link", size: 12)
                        Text(sourceLabel)
                            .font(PirateTokens.Typography.small)
                            .lineLimit(1)
                    }
                    .foregroundStyle(colors.textSecondary)
                }

                Text(post.linkTitle ?? post.linkUrl ?? titleFallback)
                    .font(compact ? PirateTokens.Typography.smallStrong : PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(compact ? 2 : 3)
                    .multilineTextAlignment(.leading)

                if let description = post.linkDescription, !description.isEmpty {
                    Text(description)
                        .font(PirateTokens.Typography.small)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(compact ? 2 : 4)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsPreviewImage, let imageURL = ApiClient.shared.publicMediaURL(from: post.linkImage) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        colors.surfaceSkeleton
                    }
                }
                .frame(width: previewImageSize, height: previewImageSize)
                .clipShape(RoundedRectangle(cornerRadius: radii.md))
                .accessibilityHidden(true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
        .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))
    }

    private func sourceLabel(for url: URL) -> String {
        url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
    }

    private static func hasText(_ value: String?) -> Bool {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
