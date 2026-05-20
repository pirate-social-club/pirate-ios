import SwiftUI

struct YourCommunitiesView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    @Environment(\.dismiss) private var dismiss
    var sessionManager: SessionManager

    @State private var communities: [SubmitCommunityOption] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if isLoading {
                        LoadingView().frame(height: 200)
                    } else if let errorMessage {
                        ErrorView(message: errorMessage, retry: load)
                    } else if communities.isEmpty {
                        EmptyStateView(
                            icon: "person.3",
                            title: "No joined communities",
                            subtitle: "Communities you join will appear here."
                        )
                    } else {
                        ForEach(communities) { community in
                            NavigationLink(value: PirateRoute.community(community.id)) {
                                HStack(spacing: 12) {
                                    CommunityAvatarView(
                                        avatarRef: community.avatarRef,
                                        communityId: community.id,
                                        displayName: community.displayName,
                                        size: 36
                                    )
                                    VStack(alignment: .leading, spacing: 4) {
                                        CommunityNameLabel(
                                            text: community.routeLabel,
                                            isUnverified: community.routeIsUnverified,
                                            font: PirateTokens.Typography.bodyStrong,
                                            color: colors.textPrimary,
                                            iconSize: 14
                                        )
                                        Text("Joined")
                                            .font(PirateTokens.Typography.small)
                                            .foregroundStyle(colors.textSecondary)
                                    }
                                    Spacer()
                                    PirateSystemIconView(systemName: "chevron.right", size: 13)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(colors.textSecondary)
                                }
                                .padding(12)
                                .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.x2l))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, PirateTokens.pageGutter)
                        }
                    }
                }
                .padding(.top, 12)
            }
            .background(colors.bgPage)
            .navigationTitle("Your communities")
            .inlineNavigationBarTitle()
            .navigationBarBackButtonHidden(true)
            .tint(colors.textPrimary)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        PirateIconView(icon: .caretLeft, size: 22, color: colors.textPrimary)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            communities = try await ApiClient.shared.postableCommunities()
                .communities
                .filter { $0.action == "compose" }
                .map {
                    SubmitCommunityOption(
                        id: $0.communityId,
                        displayName: $0.displayName,
                        routeSlug: $0.routeSlug,
                        avatarRef: $0.avatarRef
                    )
                }
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct UserProfileView: View {
    @Environment(\.pirateColors) private var colors
    let userId: String
    @State private var profile: Profile?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let profile {
                PirateProfilePage(
                    data: ProfilePageData(
                        profile: profile,
                        viewerContext: .publicProfile,
                        walletAddress: profile.primaryWalletAddress,
                        activityUserId: userId
                    )
                )
            } else if isLoading {
                LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ErrorView(message: errorMessage, retry: load)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(colors.bgPage)
        .navigationTitle(profile?.displayName ?? "Profile")
        .inlineNavigationBarTitle()
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            profile = try await ApiClient.shared.profile(userId: userId)
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

