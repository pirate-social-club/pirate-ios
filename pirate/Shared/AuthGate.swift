import SwiftUI

struct AuthGate<Content: View>: View {
    @Environment(\.pirateColors) private var colors
    let isAuthenticated: Bool
    let sessionManager: SessionManager
    @ViewBuilder let content: () -> Content

    @State private var showSignIn = false

    var body: some View {
        if sessionManager.isRestoringSession {
            LoadingView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(colors.bgPage)
        } else if isAuthenticated {
            content()
        } else {
            VStack(spacing: 16) {
                Spacer()
                PirateSystemIconView(systemName: "lock", size: 34)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(colors.textSecondary)
                Text("Sign in")
                    .font(PirateTokens.Typography.h3)
                    .foregroundStyle(colors.textPrimary)
                Text("Sign in to continue into Pirate.")
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)
                Button {
                    showSignIn = true
                } label: {
                    Text("Sign In")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textOnAccent)
                        .frame(maxWidth: 260)
                        .padding(.vertical, 12)
                        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: PirateTokens.radii.full))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, PirateTokens.pageGutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(colors.bgPage)
            .sheet(isPresented: $showSignIn) {
                SignInDrawer(sessionManager: sessionManager, isPresented: $showSignIn)
            }
        }
    }
}
