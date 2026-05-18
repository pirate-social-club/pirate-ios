import SwiftUI

struct VotePill: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    let score: Int
    let voteValue: Int?
    let disabled: Bool
    let onVote: (Int) -> Void

    var body: some View {
        HStack(spacing: 4) {
            voteButton(icon: .caretUp, value: 1, active: voteValue == 1, label: "Upvote")

            Text("\(score)")
                .font(PirateTokens.Typography.smallStrong)
                .foregroundStyle(colors.textPrimary)
                .monospacedDigit()
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
            onVote(voteValue == value ? 0 : value)
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
