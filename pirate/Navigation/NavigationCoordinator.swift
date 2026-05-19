import SwiftUI

struct NavigationCoordinator: View {
    @Environment(\.pirateColors) private var colors
    @State private var navigationPath = NavigationPath()
    @Bindable var sessionManager: SessionManager

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeView(sessionManager: sessionManager)
                .navigationDestination(for: PirateRoute.self) { route in
                    routeDestination(for: route)
                }
        }
    }

    @ViewBuilder
    private func routeDestination(for route: PirateRoute) -> some View {
        switch route {
        case .auth:
            SignInRouteView(sessionManager: sessionManager)
        case .home:
            HomeView(sessionManager: sessionManager)
        case .yourCommunities:
            YourCommunitiesView(sessionManager: sessionManager)
        case .community(let id):
            CommunityView(sessionManager: sessionManager, communityId: id)
        case .createCommunity:
            CreateCommunityView(sessionManager: sessionManager)
        case .submit:
            GlobalSubmitView(sessionManager: sessionManager)
        case .post(let id):
            PostView(sessionManager: sessionManager, postId: id)
        case .composePost(let id):
            PostComposerView(sessionManager: sessionManager, communityId: id)
        case .publicProfile(let handle):
            PublicProfileView(handle: handle)
        case .publicProfileByWallet(let address):
            PublicProfileView(handle: address, walletAddress: address)
        case .user(let id):
            UserProfileView(userId: id)
        case .settings:
            SettingsView(sessionManager: sessionManager)
        case .settingsSection(let section):
            SettingsSectionView(sessionManager: sessionManager, section: section)
        case .communityModeration(let id):
            CommunityModerationView(sessionManager: sessionManager, communityId: id, section: nil)
        case .communityModerationSection(let id, let section):
            CommunityModerationView(sessionManager: sessionManager, communityId: id, section: section)
        case .me:
            MeView(sessionManager: sessionManager)
        case .wallet:
            WalletView(sessionManager: sessionManager)
        case .chat:
            ChatPlaceholderView(sessionManager: sessionManager)
        case .chatTarget(let target):
            ChatPlaceholderView(sessionManager: sessionManager, initialTarget: target)
        case .notifications, .inbox:
            NotificationsView(sessionManager: sessionManager)
        case .onboarding:
            OnboardingView(sessionManager: sessionManager)
        case .verificationSelf(let intent):
            SelfVerificationView(sessionManager: sessionManager, intent: intent)
        case .verificationVery(let intent):
            VerificationView(sessionManager: sessionManager, provider: "very", intent: intent)
        }
    }
}
