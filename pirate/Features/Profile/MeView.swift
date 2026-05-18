import SwiftUI

struct MeView: View {
    @Environment(\.pirateColors) private var colors
    var sessionManager: SessionManager

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            Group {
                if let profile = sessionManager.profile {
                    PirateProfilePage(
                        data: ProfilePageData(
                            profile: profile,
                            viewerContext: .selfProfile,
                            walletAddress: profile.primaryWalletAddress ?? sessionManager.primaryWalletAddress
                        ),
                        editDestination: .settingsSection("profile")
                    )
                } else {
                    LoadingView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(colors.bgPage)
            .hiddenRootNavigationBar()
            .task {
                await sessionManager.refreshProfile()
            }
            .refreshable {
                await sessionManager.refreshProfile()
            }
        }
    }
}
