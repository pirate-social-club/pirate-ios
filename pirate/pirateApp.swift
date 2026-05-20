import SwiftUI
#if os(iOS)
import UIKit
#endif

@main
struct PirateApp: App {
    @State private var sessionManager = SessionManager()
    @State private var mediaPlaybackCoordinator = PirateMediaPlaybackCoordinator()

    init() {
        Self.configureNavigationAppearance()
        SessionRefresher.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(sessionManager: sessionManager)
                .pirateTheme()
                .environment(\.pirateMediaPlaybackCoordinator, mediaPlaybackCoordinator)
                .onOpenURL { url in
                    #if DEBUG
                    if Self.isDebugVeryNativeURL(url) {
                        Task { @MainActor in
                            await Self.runDebugVeryNative(sessionManager: sessionManager)
                        }
                        return
                    }
                    #endif
                    VerificationCoordinator.shared.handleOpenURL(url)
                }
        }
    }
}

private extension PirateApp {
    #if DEBUG
    static func isDebugVeryNativeURL(_ url: URL) -> Bool {
        url.scheme == "pirate" && url.host == "debug" && url.path == "/very-native"
    }

    @MainActor
    static func runDebugVeryNative(sessionManager: SessionManager) async {
        for _ in 0..<20 where !sessionManager.isAuthenticated {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let result = await VeryVerificationLauncher.launch(verificationIntent: "profile_verification")
        NSLog(
            "[VeryVerificationLauncher] debug deeplink result verified=%@ session=%@ failure=%@",
            result.verified ? "true" : "false",
            result.verificationSessionId ?? "nil",
            result.failureReason ?? "nil"
        )
        if result.verified {
            await sessionManager.refreshProfile()
        }
    }
    #endif

    static func configureNavigationAppearance() {
        #if os(iOS)
        let colors = PirateUIKitColors.self
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = colors.bgPage
        appearance.shadowColor = colors.borderSoft
        appearance.titleTextAttributes = [.foregroundColor: colors.textPrimary]
        appearance.largeTitleTextAttributes = [.foregroundColor: colors.textPrimary]

        if let backImage = UIImage(named: "caret-left")?.withRenderingMode(.alwaysTemplate) {
            appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        }

        let buttonAppearance = UIBarButtonItemAppearance(style: .plain)
        buttonAppearance.normal.titleTextAttributes = [.foregroundColor: colors.textPrimary]
        buttonAppearance.highlighted.titleTextAttributes = [.foregroundColor: colors.textSecondary]
        buttonAppearance.disabled.titleTextAttributes = [.foregroundColor: colors.textDisabled]

        let backButtonAppearance = UIBarButtonItemAppearance(style: .plain)
        backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
        backButtonAppearance.highlighted.titleTextAttributes = [.foregroundColor: UIColor.clear]
        backButtonAppearance.disabled.titleTextAttributes = [.foregroundColor: UIColor.clear]

        appearance.buttonAppearance = buttonAppearance
        appearance.doneButtonAppearance = buttonAppearance
        appearance.backButtonAppearance = backButtonAppearance

        let navigationBar = UINavigationBar.appearance()
        navigationBar.tintColor = colors.textPrimary
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.compactScrollEdgeAppearance = appearance

        UIBarButtonItem.appearance().setBackButtonTitlePositionAdjustment(
            UIOffset(horizontal: -1000, vertical: 0),
            for: .default
        )
        #endif
    }
}

#if os(iOS)
private enum PirateUIKitColors {
    static let bgPage = UIColor(red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x24 / 255.0, alpha: 1)
    static let borderSoft = UIColor(red: 0x30 / 255.0, green: 0x30 / 255.0, blue: 0x2E / 255.0, alpha: 1)
    static let textPrimary = UIColor(red: 0xC3 / 255.0, green: 0xC0 / 255.0, blue: 0xB6 / 255.0, alpha: 1)
    static let textSecondary = UIColor(red: 0xB7 / 255.0, green: 0xB5 / 255.0, blue: 0xA9 / 255.0, alpha: 1)
    static let textDisabled = UIColor(red: 0x8A / 255.0, green: 0x88 / 255.0, blue: 0x80 / 255.0, alpha: 1)
}
#endif

struct ContentView: View {
    @Bindable var sessionManager: SessionManager

    var body: some View {
        PirateScaffold(sessionManager: sessionManager)
    }
}

#Preview {
    ContentView(sessionManager: SessionManager())
        .pirateTheme()
}
