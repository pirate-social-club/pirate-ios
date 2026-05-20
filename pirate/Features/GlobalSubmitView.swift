import SwiftUI

private extension PostableCommunitySummary {
    func submitOption() -> SubmitCommunityOption? {
        guard action == "compose" || action == "unlock" else { return nil }
        return SubmitCommunityOption(
            id: communityId,
            displayName: displayName,
            routeSlug: routeSlug,
            avatarRef: avatarRef
        )
    }
}


struct GlobalSubmitView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.dismiss) private var dismiss
    var sessionManager: SessionManager

    @State private var communities: [SubmitCommunityOption] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if isLoading {
                        LoadingView().frame(height: 180)
                    } else if let errorMessage {
                        ErrorView(message: errorMessage, retry: loadCommunities)
                    } else if communities.isEmpty {
                        EmptyStateView(
                            icon: "person.3",
                            title: "No eligible communities",
                            subtitle: "Join a community before creating a post."
                        )
                    } else {
                        ForEach(communities) { community in
                            NavigationLink(value: PirateRoute.composePost(community.id)) {
                                PirateCard {
                                    HStack(spacing: 12) {
                                        CommunityAvatarView(
                                            avatarRef: community.avatarRef,
                                            communityId: community.id,
                                            displayName: community.displayName,
                                            size: 36
                                        )
                                        CommunityNameLabel(
                                            text: community.routeLabel,
                                            isUnverified: community.routeIsUnverified,
                                            font: PirateTokens.Typography.bodyStrong,
                                            color: colors.textPrimary,
                                            iconSize: 14
                                        )
                                        Spacer()
                                        PirateSystemIconView(systemName: "chevron.right")
                                            .foregroundStyle(colors.textSecondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, PirateTokens.pageGutter)
                        }
                    }
                }
                .padding(.top, 12)
            }
            .background(colors.bgPage)
            .navigationTitle("Communities")
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
            .task { await loadCommunities() }
            .refreshable { await loadCommunities() }
        }
    }

    private func loadCommunities() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            communities = try await loadPostableCommunities()
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadPostableCommunities() async throws -> [SubmitCommunityOption] {
        try await ApiClient.shared.postableCommunities()
            .communities
            .compactMap { $0.submitOption() }
    }
}

