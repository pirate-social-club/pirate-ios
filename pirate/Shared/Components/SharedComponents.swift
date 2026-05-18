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
    var components = URLComponents(string: "https://api.dicebear.com/9.x/thumbs/svg")
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
        if let url = ApiClient.shared.publicMediaURL(from: avatarRef) {
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
                        Image(systemName: "person.fill")
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
                onVote(voteValue == 1 ? 0 : 1)
            } else {
                onVote(voteValue == -1 ? 0 : -1)
            }
        } label: {
            Image(systemName: isUpvote ? "arrow.up" : "arrow.down")
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
            Image(systemName: "exclamationmark.triangle")
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
            Image(systemName: icon)
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
