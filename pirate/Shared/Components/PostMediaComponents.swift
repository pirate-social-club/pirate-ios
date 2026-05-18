import AVKit
import SwiftUI

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
            PirateVideoPlayer(url: item.sourceURL, muted: true, autoplay: true)
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
            Image(systemName: systemName)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(colors.textSecondary)
        }
    }

    private var playBadge: some View {
        Image(systemName: "play.fill")
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

                    Image(systemName: "play.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(colors.textOnAccent)
                        .frame(width: 58, height: 58)
                        .background(colors.bgOverlay, in: Circle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.title.map { "Play \($0)" } ?? "Play video")
        } else {
            PirateVideoPlayer(url: item.sourceURL, muted: false, autoplay: isPlaying)
                .aspectRatio(item.displayAspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: maxHeight)
        }
    }
}

private struct PirateVideoPlayer: View {
    let url: URL
    let muted: Bool
    let autoplay: Bool

    @State private var player = AVPlayer()
    @State private var loadedURL: URL?

    var body: some View {
        VideoPlayer(player: player)
            .background(Color.black)
            .onAppear(perform: configurePlayer)
            .onChange(of: url) { _, _ in
                configurePlayer()
            }
            .onDisappear {
                player.pause()
            }
    }

    private func configurePlayer() {
        if loadedURL != url {
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            loadedURL = url
        }
        player.isMuted = muted
        if autoplay {
            player.play()
        }
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

    var body: some View {
        if let linkURL = resolvedLinkURL {
            Link(destination: linkURL) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 12, weight: .medium))
                            Text(sourceLabel(for: linkURL))
                                .font(PirateTokens.Typography.small)
                                .lineLimit(1)
                        }
                        .foregroundStyle(colors.textSecondary)

                        Text(post.linkTitle ?? post.linkUrl ?? linkURL.absoluteString)
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

    private func sourceLabel(for url: URL) -> String {
        url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
    }
}
