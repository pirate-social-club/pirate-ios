import SwiftUI

extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension View {
    func inlineNavigationBarTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    func hiddenRootNavigationBar() -> some View {
        #if os(iOS)
        self.toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

}

func formatRelativeTimestamp(_ value: String?) -> String {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
        return ""
    }

    let date: Date?
    if let epoch = Double(value), epoch > 0 {
        let seconds = epoch > 10_000_000_000 ? epoch / 1000 : epoch
        date = Date(timeIntervalSince1970: seconds)
    } else {
        date = parseAPITimestamp(value)
    }

    guard let date else { return "" }
    let diff = Date().timeIntervalSince(date)
    let isFuture = diff < 0
    let diffMinutes = Int(abs(diff) / 60)
    if diffMinutes < 1 { return "now" }
    if diffMinutes < 60 { return isFuture ? "in \(diffMinutes)m" : "\(diffMinutes)m" }

    let diffHours = diffMinutes / 60
    if diffHours < 24 { return isFuture ? "in \(diffHours)h" : "\(diffHours)h" }

    let diffDays = diffHours / 24
    if diffDays < 7 { return isFuture ? "in \(diffDays)d" : "\(diffDays)d" }

    let diffWeeks = diffDays / 7
    if diffWeeks < 5 { return isFuture ? "in \(diffWeeks)w" : "\(diffWeeks)w" }

    let diffMonths = diffDays / 30
    if diffMonths < 12 { return isFuture ? "in \(diffMonths)mo" : "\(diffMonths)mo" }

    let diffYears = max(1, diffDays / 365)
    return isFuture ? "in \(diffYears)y" : "\(diffYears)y"
}

private func parseAPITimestamp(_ value: String) -> Date? {
    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = fractionalFormatter.date(from: value) {
        return date
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
}

struct MobilePageHeader<Actions: View>: View {
    @Environment(\.pirateColors) private var colors

    let title: String
    let actions: Actions

    init(_ title: String, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.actions = actions()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(PirateTokens.Typography.h2)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)

            Spacer()

            actions
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
}

extension MobilePageHeader where Actions == EmptyView {
    init(_ title: String) {
        self.init(title) {
            EmptyView()
        }
    }
}

struct PirateCard<Content: View>: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.lg))
            .overlay(RoundedRectangle(cornerRadius: radii.lg).stroke(colors.borderSoft, lineWidth: 1))
    }
}

private let defaultUserAvatarBackgroundColors = [
    "d9a441",
    "2f80ed",
    "27ae60",
    "eb5757",
    "9b51e0",
    "56ccf2",
    "f2994a",
    "219653",
    "bb6bd9",
    "f2c94c"
]

func buildDefaultUserAvatarURL(seedSource: String, size: Int = 128) -> URL? {
    let seed = seedSource.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !seed.isEmpty else { return nil }

    let background = defaultUserAvatarBackgroundColors[
        Int(defaultUserAvatarHash(seed) % UInt32(defaultUserAvatarBackgroundColors.count))
    ]
    var components = URLComponents(string: "https://api.dicebear.com/9.x/thumbs/png")
    components?.queryItems = [
        URLQueryItem(name: "seed", value: seed),
        URLQueryItem(name: "size", value: String(size)),
        URLQueryItem(name: "radius", value: "50"),
        URLQueryItem(name: "scale", value: "92"),
        URLQueryItem(name: "backgroundColor", value: background),
        URLQueryItem(name: "eyesColor", value: "111111"),
        URLQueryItem(name: "mouthColor", value: "111111"),
        URLQueryItem(name: "shapeColor", value: "f7f5f0,fffdf7,f6f3eb")
    ]
    return components?.url
}

private func nativeRenderableAvatarURL(from avatarRef: String?) -> URL? {
    guard let url = ApiClient.shared.publicMediaURL(from: avatarRef) else { return nil }

    if url.scheme?.lowercased() == "data" {
        return nil
    }

    if let dicebearPNG = dicebearPNGURL(from: url) {
        return dicebearPNG
    }

    if url.pathExtension.lowercased() == "svg" {
        return nil
    }

    return url
}

private func dicebearPNGURL(from url: URL) -> URL? {
    guard
        url.host?.lowercased() == "api.dicebear.com",
        url.path.hasSuffix("/svg"),
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else {
        return nil
    }

    components.path = String(components.path.dropLast(4)) + "/png"
    return components.url
}

private func defaultUserAvatarHash(_ seed: String) -> UInt32 {
    var hash: UInt32 = 2_166_136_261
    for scalar in seed.unicodeScalars {
        hash ^= scalar.value
        hash = hash &* 16_777_619
    }
    return hash
}

struct AvatarView: View {
    @Environment(\.pirateColors) private var colors
    let avatarRef: String?
    let size: CGFloat
    let fallbackLabel: String?
    let fallbackSeed: String?

    init(avatarRef: String?, size: CGFloat = 40, fallbackLabel: String? = nil, fallbackSeed: String? = nil) {
        self.avatarRef = avatarRef
        self.size = size
        self.fallbackLabel = fallbackLabel
        self.fallbackSeed = fallbackSeed
    }

    var body: some View {
        if let url = nativeRenderableAvatarURL(from: avatarRef) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure, .empty:
                    defaultAvatar
                @unknown default:
                    defaultAvatar
                }
            }
            .frame(width: size, height: size)
        } else {
            defaultAvatar
        }
    }

    @ViewBuilder
    private var defaultAvatar: some View {
        if let url = buildDefaultUserAvatarURL(seedSource: fallbackSeed ?? fallbackLabel ?? "") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure, .empty:
                    placeholder
                @unknown default:
                    placeholder
                }
            }
            .frame(width: size, height: size)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(colors.surfaceSkeleton)
            .frame(width: size, height: size)
            .overlay(
                Group {
                    if let initials = fallbackInitials {
                        Text(initials)
                            .font(.system(size: size * 0.32, weight: .semibold))
                    } else {
                        PirateSystemIconView(systemName: "person.fill", size: size * 0.4)
                            .font(.system(size: size * 0.4))
                    }
                }
                .foregroundStyle(colors.textSecondary)
            )
    }

    private var fallbackInitials: String? {
        guard let fallbackLabel else { return nil }
        let trimmed = fallbackLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(2)).uppercased()
    }
}

struct CommunityRoleIconBadgeView: View {
    @Environment(\.pirateColors) private var colors
    let role: String?
    var size: CGFloat = 16

    private var normalizedRole: String? {
        guard let role = role?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !role.isEmpty else {
            return nil
        }
        if role == "owner" { return "owner" }
        if role == "admin" || role == "moderator" { return "moderator" }
        return nil
    }

    @ViewBuilder
    var body: some View {
        if let normalizedRole {
            PirateIconView(
                icon: normalizedRole == "owner" ? .crownCross : .shield,
                filled: true,
                size: size,
                color: normalizedRole == "owner" ? colors.accentWarning : colors.textSecondary
            )
            .accessibilityLabel(normalizedRole == "owner" ? "Owner" : "Moderator")
        }
    }
}

struct CommunityNameLabel: View {
    @Environment(\.pirateColors) private var colors

    let text: String
    let isUnverified: Bool
    var font: Font = PirateTokens.Typography.smallStrong
    var color: Color? = nil
    var iconSize: CGFloat = 13
    var lineLimit: Int? = 1

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(font)
                .foregroundStyle(color ?? colors.textPrimary)
                .lineLimit(lineLimit)
                .layoutPriority(1)

            if isUnverified {
                PirateIconView(
                    icon: .warningCircle,
                    filled: true,
                    size: iconSize,
                    color: colors.accentWarning
                )
                .accessibilityLabel("Unverified community")
            }
        }
    }
}

struct VoteButton: View {
    @Environment(\.pirateColors) private var colors
    let voteValue: Int?
    let onVote: (Int) -> Void
    let isUpvote: Bool

    init(voteValue: Int?, onVote: @escaping (Int) -> Void, isUpvote: Bool = true) {
        self.voteValue = voteValue
        self.onVote = onVote
        self.isUpvote = isUpvote
    }

    var body: some View {
        Button {
            if isUpvote {
                guard voteValue != 1 else { return }
                onVote(1)
            } else {
                guard voteValue != -1 else { return }
                onVote(-1)
            }
        } label: {
            PirateSystemIconView(systemName: isUpvote ? "arrow.up" : "arrow.down", size: 16)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isActive ? colors.accentBrand : colors.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var isActive: Bool {
        guard let voteValue = voteValue else { return false }
        return isUpvote ? voteValue == 1 : voteValue == -1
    }
}

struct SectionHeader: View {
    @Environment(\.pirateColors) private var colors
    let title: String

    var body: some View {
        Text(title)
            .font(PirateTokens.Typography.h3)
            .foregroundStyle(colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LoadingView: View {
    @Environment(\.pirateColors) private var colors

    var body: some View {
        ProgressView()
            .tint(colors.accentBrand)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    @Environment(\.pirateColors) private var colors
    let message: String
    let retry: (() async -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            PirateSystemIconView(systemName: "exclamationmark.triangle", size: 32)
                .font(.system(size: 32))
                .foregroundStyle(colors.accentWarning)
            Text(message)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
            if let retry = retry {
                Button("Try Again") {
                    Task { await retry() }
                }
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(colors.accentBrand)
            }
        }
        .padding(32)
    }
}

struct EmptyStateView: View {
    @Environment(\.pirateColors) private var colors
    let icon: String
    let title: String
    let subtitle: String?

    init(icon: String, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 12) {
            PirateSystemIconView(systemName: icon, size: 40)
                .font(.system(size: 40))
                .foregroundStyle(colors.textSecondary)
            Text(title)
                .font(PirateTokens.Typography.h4)
                .foregroundStyle(colors.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
    }
}
