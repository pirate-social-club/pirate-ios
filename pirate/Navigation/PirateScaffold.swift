import SwiftUI

struct PirateScaffold: View {
    @Environment(\.pirateColors) private var colors
    @State private var selectedTab: PirateTab = .home
    @State private var homePath: [PirateRoute] = []
    @State private var walletPath: [PirateRoute] = []
    @State private var chatPath: [PirateRoute] = []
    @State private var notificationsPath: [PirateRoute] = []
    @State private var mePath: [PirateRoute] = []
    @Bindable var sessionManager: SessionManager

    var body: some View {
        selectedTabContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !currentRouteHidesFooter {
                    bottomBar
                }
            }
            .background(colors.bgPage.ignoresSafeArea())
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .home:
            NavigationStack(path: $homePath) {
                HomeView(sessionManager: sessionManager)
                    .navigationDestination(for: PirateRoute.self) { route in
                        routeDestination(for: route)
                    }
            }
        case .wallet:
            NavigationStack(path: $walletPath) {
                WalletView(sessionManager: sessionManager)
                    .navigationDestination(for: PirateRoute.self) { route in
                        routeDestination(for: route)
                    }
            }
        case .chat:
            NavigationStack(path: $chatPath) {
                ChatPlaceholderView(sessionManager: sessionManager)
                    .navigationDestination(for: PirateRoute.self) { route in
                        routeDestination(for: route)
                    }
            }
        case .notifications:
            NavigationStack(path: $notificationsPath) {
                NotificationsView(sessionManager: sessionManager)
                    .navigationDestination(for: PirateRoute.self) { route in
                        routeDestination(for: route)
                    }
            }
        case .me:
            NavigationStack(path: $mePath) {
                MeView(sessionManager: sessionManager)
                    .navigationDestination(for: PirateRoute.self) { route in
                        routeDestination(for: route)
                    }
            }
        }
    }

    private var currentRouteHidesFooter: Bool {
        switch selectedTab {
        case .home:
            return homePath.last?.hidesMobileFooter ?? false
        case .wallet:
            return walletPath.last?.hidesMobileFooter ?? false
        case .chat:
            return chatPath.last?.hidesMobileFooter ?? false
        case .notifications:
            return notificationsPath.last?.hidesMobileFooter ?? false
        case .me:
            return mePath.last?.hidesMobileFooter ?? false
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(PirateTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .frame(height: bottomBarHeight)
        .frame(maxWidth: .infinity)
        .background(colors.bgPage)
        .overlay(Rectangle().fill(colors.borderSoft).frame(height: 0.5), alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var bottomBarHeight: CGFloat {
        56
    }

    private func tabButton(_ tab: PirateTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            let isSelected = selectedTab == tab
            PirateIconView(
                icon: tab.icon,
                filled: isSelected,
                size: 24,
                color: isSelected ? colors.textPrimary : colors.textSecondary
            )
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(tab.rawValue)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func routeDestination(for route: PirateRoute) -> some View {
        switch route {
        case .auth:
            SignInRouteView(sessionManager: sessionManager)
        case .onboarding:
            OnboardingView(sessionManager: sessionManager)
        case .home:
            HomeView(sessionManager: sessionManager)
        case .chat:
            ChatPlaceholderView(sessionManager: sessionManager)
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
        case .notifications, .inbox:
            NotificationsView(sessionManager: sessionManager)
        case .wallet:
            WalletView(sessionManager: sessionManager)
        case .me:
            MeView(sessionManager: sessionManager)
        case .settings:
            SettingsView(sessionManager: sessionManager)
        case .settingsSection(let section):
            SettingsSectionView(sessionManager: sessionManager, section: section)
        case .communityModeration(let id):
            CommunityModerationView(sessionManager: sessionManager, communityId: id, section: nil)
        case .communityModerationSection(let id, let section):
            CommunityModerationView(sessionManager: sessionManager, communityId: id, section: section)
        case .user(let id):
            UserProfileView(userId: id)
        case .publicProfile(let handle):
            PublicProfileView(handle: handle)
        case .publicProfileByWallet(let address):
            PublicProfileView(handle: address, walletAddress: address)
        case .verificationSelf(let intent):
            VerificationView(sessionManager: sessionManager, provider: "self", intent: intent)
        case .verificationVery:
            VerificationView(sessionManager: sessionManager, provider: "very", intent: "profile_verification")
        }
    }
}

struct SignInRouteView: View {
    @Bindable var sessionManager: SessionManager
    @State private var isPresented = true

    var body: some View {
        EmptyStateView(icon: "lock", title: "Sign in", subtitle: nil)
            .sheet(isPresented: $isPresented) {
                SignInDrawer(sessionManager: sessionManager, isPresented: $isPresented)
            }
    }
}
