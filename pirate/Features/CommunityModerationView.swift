import SwiftUI

struct CommunityModerationView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    var sessionManager: SessionManager
    let communityId: String
    let section: String?

    @State private var community: Community?
    @State private var namespaceSession: NamespaceVerificationSession?
    @State private var family = "hns"
    @State private var rootLabel = ""
    @State private var isLoading = true
    @State private var isWorking = false
    @State private var message: String?
    @State private var errorMessage: String?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if section == "namespace" {
                        namespaceBody
                    } else {
                        moderationIndex
                    }
                }
                .padding(PirateTokens.pageGutter)
            }
            .background(colors.bgPage)
            .navigationTitle(sectionTitle)
            .inlineNavigationBarTitle()
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var sectionTitle: String {
        section == nil ? "Moderation" : section!.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }

    private var moderationIndex: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(community?.displayName ?? "Community moderation")
                .font(PirateTokens.Typography.h2)
                .foregroundStyle(colors.textPrimary)
            ForEach(PirateRoute.moderationSections.sorted(), id: \.self) { item in
                NavigationLink(value: PirateRoute.communityModerationSection(communityId, item)) {
                    PirateCard {
                        HStack {
                            Text(item.split(separator: "-").map { $0.capitalized }.joined(separator: " "))
                                .font(PirateTokens.Typography.bodyStrong)
                                .foregroundStyle(colors.textPrimary)
                            Spacer()
                            PirateSystemIconView(systemName: "chevron.right").foregroundStyle(colors.textSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var namespaceBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isLoading {
                LoadingView().frame(height: 180)
            }

            if let message {
                Text(message)
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.accentSuccess)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.accentDanger)
            }

            PirateCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Verify a namespace")
                        .font(PirateTokens.Typography.h3)
                        .foregroundStyle(colors.textPrimary)
                    Picker("Family", selection: $family) {
                        Text("HNS").tag("hns")
                        Text("Spaces").tag("spaces")
                    }
                    .pickerStyle(.segmented)
                    TextField("Root label", text: $rootLabel)
                        .textFieldStyle(.plain)
                        .font(PirateTokens.Typography.body)
                        .foregroundStyle(colors.textPrimary)
                        .padding(12)
                        .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
                    Button {
                        Task { await startNamespaceSession() }
                    } label: {
                        Text(namespaceSession == nil ? "Start verification" : "Start new challenge")
                            .font(PirateTokens.Typography.bodyStrong)
                            .foregroundStyle(colors.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                    }
                    .buttonStyle(.plain)
                    .disabled(rootLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isWorking)
                }
            }

            if let namespaceSession {
                PirateCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Challenge")
                            .font(PirateTokens.Typography.h3)
                            .foregroundStyle(colors.textPrimary)
                        Text("Status: \(namespaceSession.status ?? "pending")")
                            .font(PirateTokens.Typography.body)
                            .foregroundStyle(colors.textSecondary)
                        challengeValue("Host", namespaceSession.challengeHost)
                        challengeValue("TXT value", namespaceSession.challengeTxtValue)
                        challengeValue("Expires", namespaceSession.challengeExpiresAt)
                        if let failure = namespaceSession.failureReason {
                            Text(failure).foregroundStyle(colors.accentDanger)
                        }
                        Button {
                            Task { await completeNamespaceSession() }
                        } label: {
                            Text(isWorking ? "Checking..." : "Check verification")
                                .font(PirateTokens.Typography.bodyStrong)
                                .foregroundStyle(colors.textOnAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                        }
                        .buttonStyle(.plain)
                        .disabled(isWorking)
                    }
                }
            }

            if community?.namespaceVerificationId != nil {
                NavigationLink(value: PirateRoute.community(communityId)) {
                    Text("Open community")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(colors.accentSuccess, in: RoundedRectangle(cornerRadius: radii.full))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func challengeValue(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            Text(label)
                .font(PirateTokens.Typography.smallStrong)
                .foregroundStyle(colors.textSecondary)
            Text(value)
                .font(PirateTokens.Typography.caption)
                .foregroundStyle(colors.textPrimary)
                .textSelection(.enabled)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await ApiClient.shared.communityDetails(id: communityId)
            community = loaded
            rootLabel = namespaceSession?.submittedRootLabel ?? loaded.routeSlug ?? rootLabel
            if let sessionId = loaded.pendingNamespaceVerificationSessionId {
                namespaceSession = try? await ApiClient.shared.namespaceSession(id: sessionId)
                rootLabel = namespaceSession?.submittedRootLabel ?? rootLabel
                family = namespaceSession?.family ?? family
            }
            message = loaded.namespaceVerificationId != nil ? "Namespace verified." : nil
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func startNamespaceSession() async {
        isWorking = true
        errorMessage = nil
        do {
            let session = try await ApiClient.shared.startNamespaceSession(
                family: family,
                rootLabel: rootLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            namespaceSession = session
            community = try await ApiClient.shared.setPendingNamespaceSession(communityId: communityId, sessionId: session.id)
            message = "Namespace challenge started."
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }

    private func completeNamespaceSession() async {
        guard let namespaceSession else { return }
        isWorking = true
        errorMessage = nil
        do {
            let completed = try await ApiClient.shared.completeNamespaceSession(id: namespaceSession.id)
            self.namespaceSession = completed
            if completed.status == "verified", let namespaceId = completed.namespaceVerificationId {
                community = try await ApiClient.shared.attachNamespace(communityId: communityId, namespaceVerificationId: namespaceId)
            }
            message = completed.status == "verified" ? "Namespace verified." : "Verification status: \(completed.status ?? "pending")."
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
