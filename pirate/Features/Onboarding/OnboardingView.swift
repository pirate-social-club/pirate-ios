import SwiftUI

struct OnboardingView: View {
    @Environment(\.pirateColors) private var colors
    var sessionManager: SessionManager

    @State private var onboardingStatus: OnboardingStatus?

    var body: some View {
        VStack(spacing: 24) {
            PirateSystemIconView(systemName: "flag.checkered", size: 48)
                .font(.system(size: 48))
                .foregroundStyle(colors.accentBrand)

            Text("Welcome to Pirate")
                .font(PirateTokens.Typography.h2)
                .foregroundStyle(colors.textPrimary)

            Text("Set up your profile to get started.")
                .font(PirateTokens.Typography.caption)
                .foregroundStyle(colors.textSecondary)

            Button {
                Task { await dismissOnboarding() }
            } label: {
                Text("Get Started")
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textOnAccent)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: PirateTokens.radii.full))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.bgPage)
        .navigationTitle("Onboarding")
        .task {
            await loadOnboardingStatus()
        }
    }

    private func loadOnboardingStatus() async {
        do {
            onboardingStatus = try await ApiClient.shared.onboardingStatus()
        } catch {}
    }

    private func dismissOnboarding() async {
        do {
            try await ApiClient.shared.dismissOnboarding()
        } catch {}
    }
}
