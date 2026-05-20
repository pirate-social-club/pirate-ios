import SwiftUI

private struct PirateNavigateRouteKey: EnvironmentKey {
    static let defaultValue: (PirateRoute) -> Void = { _ in }
}

extension EnvironmentValues {
    var navigatePirateRoute: (PirateRoute) -> Void {
        get { self[PirateNavigateRouteKey.self] }
        set { self[PirateNavigateRouteKey.self] = newValue }
    }
}

enum PirateRoute: Hashable {
    case auth
    case onboarding
    case home
    case chat
    case chatTarget(String)
    case yourCommunities
    case community(String)
    case createCommunity
    case submit
    case post(String)
    case composePost(String)
    case notifications
    case inbox
    case wallet
    case me
    case settings
    case settingsSection(String)
    case communityModeration(String)
    case communityModerationSection(String, String)
    case user(String)
    case publicProfile(String)
    case publicProfileByWallet(String)
    case verificationSelf(String)
    case verificationVery(String)

    var path: String {
        switch self {
        case .auth: return "auth"
        case .onboarding: return "onboarding"
        case .home: return "home"
        case .chat: return "chat"
        case .chatTarget(let target): return "chat/\(target)"
        case .yourCommunities: return "your_communities"
        case .community(let id): return "community/\(id)"
        case .createCommunity: return "communities/new"
        case .submit: return "submit"
        case .post(let id): return "post/\(id)"
        case .composePost(let id): return "community/\(id)/compose"
        case .notifications: return "notifications"
        case .inbox: return "inbox"
        case .wallet: return "wallet"
        case .me: return "me"
        case .settings: return "settings"
        case .settingsSection(let section): return "settings/\(section)"
        case .communityModeration(let id): return "community/\(id)/mod"
        case .communityModerationSection(let id, let section): return "community/\(id)/mod/\(section)"
        case .user(let id): return "user/\(id)"
        case .publicProfile(let handle): return "public-profile/\(handle)"
        case .publicProfileByWallet(let address): return "public-profile/wallet/\(address)"
        case .verificationSelf(let intent): return "verification/self/\(intent)"
        case .verificationVery(let intent): return "verification/very/\(intent)"
        }
    }

    var hidesMobileFooter: Bool {
        switch self {
        case .post:
            return true
        default:
            return false
        }
    }

    static let verificationIntents: Set<String> = [
        "profile_verification",
        "community_creation",
        "community_join",
        "post_access_18_plus",
        "commerce_pricing",
        "qualifier_disclosure"
    ]

    static let settingsSections: Set<String> = [
        "profile", "domains", "preferences", "agents"
    ]

    static let moderationSections: Set<String> = [
        "queue", "profile", "rules", "links", "labels", "donations",
        "pricing", "requests", "namespace", "handles", "gates",
        "safety", "visual-policy", "agents", "machine-access"
    ]
}

enum PirateTab: String, CaseIterable {
    case home = "Home"
    case wallet = "Wallet"
    case chat = "Chat"
    case notifications = "Notifications"
    case me = "Profile"

    var icon: PirateIcon {
        switch self {
        case .home: return .house
        case .wallet: return .wallet
        case .chat: return .chatCircle
        case .notifications: return .bell
        case .me: return .userCircle
        }
    }

    var route: PirateRoute {
        switch self {
        case .home: return .home
        case .wallet: return .wallet
        case .chat: return .chat
        case .notifications: return .notifications
        case .me: return .me
        }
    }
}
