import SwiftUI

struct PublicProfileView: View {
    @Environment(\.pirateColors) private var colors

    let handle: String
    let walletAddress: String?
    let onMessage: ((String) -> Void)?

    init(handle: String, walletAddress: String? = nil, onMessage: ((String) -> Void)? = nil) {
        self.handle = handle
        self.walletAddress = walletAddress
        self.onMessage = onMessage
    }

    @State private var profileResolution: PublicProfileResolution?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var loadKey: String {
        "\(handle):\(walletAddress ?? "")"
    }

    var body: some View {
        Group {
            if let resolution = profileResolution {
                let profile = resolution.profile
                PirateProfilePage(
                    data: ProfilePageData(
                        profile: profile,
                        viewerContext: .publicProfile,
                        walletAddress: profile.primaryWalletAddress ?? walletAddress,
                        activityHandle: resolution.resolvedHandleLabels?.first ?? (walletAddress == nil ? handle : nil)
                    ),
                    onMessage: onMessage
                )
            } else if isLoading {
                LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ErrorView(message: errorMessage, retry: loadProfile)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(colors.bgPage)
        .navigationTitle(profileResolution?.resolvedHandleLabels?.first ?? handle)
        .inlineNavigationBarTitle()
        .task(id: loadKey) {
            await loadProfile()
        }
        .refreshable {
            await loadProfile()
        }
    }

    private func loadProfile() async {
        isLoading = true
        errorMessage = nil
        profileResolution = nil
        do {
            let wallet = walletAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let wallet, !wallet.isEmpty {
                profileResolution = try await ApiClient.shared.publicProfileByWallet(address: wallet)
            } else {
                profileResolution = try await ApiClient.shared.publicProfile(handle: handle)
            }
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
