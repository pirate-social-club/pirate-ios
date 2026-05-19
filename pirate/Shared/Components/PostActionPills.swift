import SwiftUI

struct VotePill: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    let score: Int
    let voteValue: Int?
    let disabled: Bool
    var isWorking = false
    let onVote: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            voteButton(icon: .caretUp, value: 1, active: voteValue == 1, label: "Upvote")

            Group {
                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                        .tint(colors.textSecondary)
                } else {
                    Text("\(score)")
                        .font(PirateTokens.Typography.smallStrong)
                        .foregroundStyle(colors.textPrimary)
                        .monospacedDigit()
                }
            }
            .frame(minWidth: 16)

            voteButton(icon: .caretDown, value: -1, active: voteValue == -1, label: "Downvote")
        }
        .padding(.horizontal, 5)
        .frame(height: 38)
        .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.full))
        .overlay(RoundedRectangle(cornerRadius: radii.full).stroke(colors.borderSoft, lineWidth: 1))
        .opacity(disabled ? 0.55 : 1)
    }

    private func voteButton(icon: PirateIcon, value: Int, active: Bool, label: String) -> some View {
        Button {
            guard voteValue != value else { return }
            onVote(value)
        } label: {
            PirateIconView(icon: icon, size: 17, color: active ? colors.accentBrand : colors.textSecondary)
                .frame(width: 28, height: 30)
        }
        .disabled(disabled)
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct CommentCountPill: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    let count: Int

    var body: some View {
        HStack(spacing: 7) {
            PirateIconView(icon: .chatCircle, size: 17, color: colors.textPrimary)
            Text("\(count)")
                .font(PirateTokens.Typography.smallStrong)
                .monospacedDigit()
        }
        .foregroundStyle(colors.textPrimary)
        .padding(.horizontal, 13)
        .frame(height: 38)
        .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.full))
        .overlay(RoundedRectangle(cornerRadius: radii.full).stroke(colors.borderSoft, lineWidth: 1))
        .accessibilityLabel("\(count) comments")
    }
}

struct ReplyActionPill: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    let title: String
    let isActive: Bool
    let onReply: () -> Void

    init(title: String = "Reply", isActive: Bool = false, onReply: @escaping () -> Void) {
        self.title = title
        self.isActive = isActive
        self.onReply = onReply
    }

    var body: some View {
        Button {
            onReply()
        } label: {
            HStack(spacing: 7) {
                PirateIconView(icon: .chatCircle, size: 17, color: foregroundColor)
                Text(title)
                    .font(PirateTokens.Typography.smallStrong)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 13)
            .frame(height: 38)
            .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.full))
            .overlay(RoundedRectangle(cornerRadius: radii.full).stroke(borderColor, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var foregroundColor: Color {
        isActive ? colors.accentBrand : colors.textPrimary
    }

    private var borderColor: Color {
        isActive ? colors.accentBrand.opacity(0.35) : colors.borderSoft
    }
}
