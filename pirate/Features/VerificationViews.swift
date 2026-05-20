import SwiftUI

private enum SelfVerificationScreenState {
    case notStarted
    case pending
    case verified
}

struct SelfVerificationView: View {
    var sessionManager: SessionManager
    let intent: String
    var requestedCapabilities: [String] = ["unique_human"]
    var verificationRequirements: [VerificationRequirement] = []
    var onVerified: (() async -> Void)?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            SelfVerificationFlowContent(
                sessionManager: sessionManager,
                intent: intent,
                requestedCapabilities: requestedCapabilities,
                verificationRequirements: verificationRequirements,
                onVerified: onVerified
            )
            .navigationTitle("Verify with ID")
        }
    }
}

struct SelfVerificationDrawer: View {
    var sessionManager: SessionManager
    let intent: String
    var requestedCapabilities: [String] = ["unique_human"]
    var verificationRequirements: [VerificationRequirement] = []
    @Binding var isPresented: Bool
    var onVerified: (() async -> Void)?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            SelfVerificationFlowContent(
                sessionManager: sessionManager,
                intent: intent,
                requestedCapabilities: requestedCapabilities,
                verificationRequirements: verificationRequirements,
                onVerified: onVerified,
                onClose: { isPresented = false }
            )
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }
}

private struct SelfVerificationFlowContent: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    @Environment(\.openURL) private var openURL
    var sessionManager: SessionManager
    let intent: String
    var requestedCapabilities: [String]
    var verificationRequirements: [VerificationRequirement]
    var onVerified: (() async -> Void)?
    var onClose: (() -> Void)?

    @State private var coordinator = VerificationCoordinator.shared
    @State private var session: VerificationSession?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var screenState: SelfVerificationScreenState = .notStarted
    @State private var completingSessionId: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(colors.surfaceAccent)
                                .frame(width: 52, height: 52)
                                .overlay(
                                    PirateIconView(icon: .identificationCard, filled: true, size: 26, color: colors.accentBrand)
                                )
                            Text("Verify with ID")
                                .font(PirateTokens.Typography.h2)
                                .foregroundStyle(colors.textPrimary)
                        }
                        Text(descriptionText)
                            .font(PirateTokens.Typography.body)
                            .foregroundStyle(colors.textSecondary)
                    }
                    Spacer()
                    if let onClose {
                        Button {
                            onClose()
                        } label: {
                            PirateIconView(icon: .x, size: 16, color: colors.textSecondary)
                                .frame(width: 34, height: 34)
                                .background(colors.surfaceSubtle, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let errorMessage {
                    statusNote(errorMessage, color: colors.accentDanger)
                }

                VStack(alignment: .leading, spacing: 14) {
                    switch screenState {
                    case .verified:
                        statusNote("Verification complete.", color: colors.accentSuccess)
                    case .pending:
                        statusNote("Complete the Self flow, then return here.", color: colors.textSecondary)
                        Button {
                            Task { await reopenVerification() }
                        } label: {
                            buttonLabel(isLoading ? "Opening..." : "Reopen Self")
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    case .notStarted:
                        Button {
                            Task { await start() }
                        } label: {
                            buttonLabel(isLoading ? "Opening..." : "Open Self")
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    }
                }

                appDownloadSection
            }
            .padding(PirateTokens.pageGutter)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .task {
                await checkExistingVerification()
            }
            .task(id: coordinator.callbackResult) {
                guard let result = coordinator.callbackResult else { return }
                await handleCallback(result)
            }
        }
        .background(colors.bgPage)
    }

    private var descriptionText: String {
        if verificationRequirements.contains(where: { $0.proofType == "nationality" }) {
            return "Self.xyz lets you prove your nationality without sharing your name, photo, or document details with anyone."
        }
        if verificationRequirements.contains(where: { $0.proofType == "minimum_age" }) || requestedCapabilities.contains("age_over_18") {
            return "Self.xyz lets you prove your age without sharing your name, photo, or document details with anyone."
        }
        if requestedCapabilities.contains("gender") {
            return "Self.xyz lets you prove facts from your ID without sharing your name, photo, or document details with anyone."
        }
        return "Self.xyz lets you prove facts like age and nationality without sharing your name, photo, or document details with anyone."
    }

    private func statusNote(_ text: String, color: Color) -> some View {
        Text(text)
            .font(PirateTokens.Typography.body)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.md))
    }

    private var appDownloadSection: some View {
        Link(destination: selfAppStoreURL) {
            outlineButtonLabel("Install Self")
        }
        .buttonStyle(.plain)
    }

    private var selfAppStoreURL: URL {
        URL(string: "https://apps.apple.com/us/app/self-zk-passport-identity/id6478563710")!
    }

    private func buttonLabel(_ title: String) -> some View {
        HStack {
            if isLoading { ProgressView().tint(colors.textOnAccent) }
            Text(title)
        }
        .font(PirateTokens.Typography.bodyStrong)
        .foregroundStyle(colors.textOnAccent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
    }

    private func outlineButtonLabel(_ title: String) -> some View {
        HStack(spacing: 8) {
            PirateIconView(icon: .arrowSquareOut, size: 16, color: colors.textPrimary)
            Text(title)
        }
        .font(PirateTokens.Typography.bodyStrong)
        .foregroundStyle(colors.textPrimary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.full))
        .overlay(
            RoundedRectangle(cornerRadius: radii.full)
                .stroke(colors.borderDefault, lineWidth: 1)
        )
    }

    private func start() async {
        isLoading = true
        errorMessage = nil
        do {
            let createdSession = try await ApiClient.shared.startVerificationSession(sessionRequest: StartVerificationSessionRequest(
                provider: "self",
                providerMode: "qr_deeplink",
                requestedCapabilities: normalizedRequestedCapabilities,
                verificationRequirements: normalizedVerificationRequirements,
                verificationIntent: intent
            ))
            coordinator.savePendingSession(PendingVerificationSession(
                provider: "self",
                verificationSessionId: createdSession.id
            ))

            guard let callbackURL = VerificationCoordinator.buildCallbackURL(
                verificationSessionId: createdSession.id,
                provider: "self"
            ) else {
                coordinator.clearPendingSession()
                throw SelfVerificationError(message: "Could not build Self callback link.")
            }

            let launchResult = SelfVerificationLaunchBuilder.buildLaunchURL(
                from: createdSession.launch,
                callbackURL: callbackURL
            )
            guard let launchURL = launchResult.url else {
                coordinator.clearPendingSession()
                throw SelfVerificationError(message: "Could not build verification link. Please try again.")
            }

            session = createdSession
            screenState = .pending
            openSelf(launchURL)
        } catch let error as ApiError {
            errorMessage = startErrorMessage(for: error)
        } catch let error as SelfVerificationError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private var normalizedRequestedCapabilities: [String]? {
        let allowed = ["unique_human", "age_over_18", "nationality", "gender"]
        let values = requestedCapabilities.filter { allowed.contains($0) }
        return values.isEmpty && verificationRequirements.isEmpty ? ["unique_human"] : values
    }

    private var normalizedVerificationRequirements: [VerificationRequirement]? {
        verificationRequirements.isEmpty ? nil : verificationRequirements
    }

    private func checkExistingVerification() async {
        guard screenState == .notStarted, !isLoading else { return }
        do {
            let status = try await ApiClient.shared.onboardingStatus()
            if status.uniqueHumanVerificationStatus == "verified" {
                screenState = .verified
            }
        } catch {
            // The verification screen can still start a fresh Self session if status refresh fails.
        }
    }

    private func reopenVerification() async {
        guard let sessionId = session?.id ?? coordinator.readPendingSession()?.verificationSessionId else { return }
        isLoading = true
        errorMessage = nil
        do {
            let refreshedSession = try await ApiClient.shared.verificationSession(id: sessionId)
            coordinator.savePendingSession(PendingVerificationSession(provider: "self", verificationSessionId: sessionId))
            guard let callbackURL = VerificationCoordinator.buildCallbackURL(verificationSessionId: sessionId, provider: "self") else {
                throw SelfVerificationError(message: "Could not build Self callback link.")
            }
            let launchResult = SelfVerificationLaunchBuilder.buildLaunchURL(from: refreshedSession.launch, callbackURL: callbackURL)
            guard let launchURL = launchResult.url else {
                throw SelfVerificationError(message: "Could not build verification link. Please try again.")
            }
            session = refreshedSession
            screenState = .pending
            openSelf(launchURL)
        } catch let error as ApiError {
            errorMessage = startErrorMessage(for: error)
        } catch let error as SelfVerificationError {
            errorMessage = error.message
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func handleCallback(_ result: VerificationCallbackResult) async {
        guard result.provider == "self" else { return }

        switch result {
        case .completed(_, let verificationSessionId, let proof):
            await completeVerification(sessionId: verificationSessionId ?? session?.id, proof: proof)
        case .expired:
            coordinator.clearPendingSession()
            coordinator.clearCallbackResult()
            screenState = .notStarted
            errorMessage = "Verification session expired. Please try again."
        case .failed(_, _, let reason):
            coordinator.clearPendingSession()
            coordinator.clearCallbackResult()
            screenState = .notStarted
            errorMessage = reason
        }
    }

    private func completeVerification(sessionId: String?, proof: String) async {
        guard let sessionId else { return }
        if completingSessionId == sessionId { return }
        completingSessionId = sessionId
        isLoading = true
        errorMessage = nil

        do {
            let completedSession = try await ApiClient.shared.completeVerificationSession(
                id: sessionId,
                request: CompleteVerificationSessionRequest(proof: proof)
            )
            session = completedSession
            coordinator.clearCallbackResult()
            coordinator.clearPendingSession()

            switch completedSession.status {
            case "verified":
                screenState = .verified
                await sessionManager.refreshUser()
                await sessionManager.refreshProfile()
                if let onVerified {
                    await onVerified()
                }
            case "expired":
                screenState = .notStarted
                errorMessage = "Verification session expired. Please try again."
            case "failed":
                screenState = .notStarted
                errorMessage = "Could not complete verification."
            default:
                screenState = .pending
            }
        } catch let error as ApiError {
            completingSessionId = nil
            errorMessage = error.displayMessage
        } catch {
            completingSessionId = nil
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func openSelf(_ url: URL) {
        openURL(url) { accepted in
            if !accepted {
                errorMessage = "Could not open Self. If it is not installed, use Install Self below."
            }
        }
    }

    private func startErrorMessage(for error: ApiError) -> String {
        guard case .serverError(let statusCode, _, let code, _, _) = error else {
            return error.displayMessage
        }
        if code == "provider_unavailable" || statusCode == 501 || statusCode == 502 {
            return "Verification provider is temporarily unavailable. Please try again later."
        }
        if code == "internal_error" || statusCode >= 500 {
            return "Could not start ID verification. Please try again."
        }
        return error.displayMessage
    }
}

private struct SelfVerificationError: Error {
    let message: String
}

struct VerificationView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    @Environment(\.openURL) private var openURL
    var sessionManager: SessionManager
    let provider: String
    let intent: String

    @State private var session: VerificationSession?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Circle()
                        .fill(colors.surfaceAccent)
                        .frame(width: 52, height: 52)
                        .overlay(
                            PirateIconView(
                                icon: provider == "very" ? .handPalm : .checkCircle,
                                filled: true,
                                size: 28,
                                color: colors.textPrimary
                            )
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(provider == "very" ? "Prove you're human" : "Verification")
                            .font(PirateTokens.Typography.h2)
                            .foregroundStyle(colors.textPrimary)
                        Text(provider == "very" ? "Scan your palm with VeryAI to prove you're a unique human." : "Complete verification to continue.")
                            .font(PirateTokens.Typography.caption)
                            .foregroundStyle(colors.textSecondary)
                    }
                }

                if let session {
                    PirateCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(statusTitle(for: session))
                                .font(PirateTokens.Typography.bodyStrong)
                                .foregroundStyle(colors.textPrimary)
                            Text(statusDescription(for: session))
                                .font(PirateTokens.Typography.caption)
                                .foregroundStyle(colors.textSecondary)

                            if launchURL(from: session) != nil {
                                Button {
                                    openLaunchURL(for: session)
                                } label: {
                                    verificationButtonLabel(provider == "very" ? "Open Very" : "Open verification", loading: false)
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                Task { await refreshSession() }
                            } label: {
                                verificationOutlineButtonLabel(isLoading ? "Checking..." : "Check status")
                            }
                            .buttonStyle(.plain)
                            .disabled(isLoading)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.accentDanger)
                }

                Button {
                    Task { await start() }
                } label: {
                    verificationButtonLabel(
                        isLoading ? "Starting..." : (provider == "very" ? "Verify" : "Start verification"),
                        loading: isLoading
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                if let download = mobileAppDownload {
                    appDownloadSection(download)
                }

                Spacer()
            }
            .padding(PirateTokens.pageGutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(colors.bgPage)
            .navigationTitle(provider == "very" ? "Palm scan" : "Verification")
        }
    }

    private func start() async {
        if provider == "very" {
            await startVeryNative()
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let createdSession = try await ApiClient.shared.startVerificationSession(sessionRequest: StartVerificationSessionRequest(
                provider: provider,
                providerMode: nil,
                requestedCapabilities: nil,
                verificationIntent: intent
            ))
            session = createdSession
            openLaunchURL(for: createdSession)
        } catch let error as ApiError {
            errorMessage = startErrorMessage(for: error)
            if shouldOpenInstallFallback(for: error) {
                openMobileAppStore()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func startVeryNative() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let result = await VeryVerificationLauncher.launch(verificationIntent: intent)
        session = result.session
        if result.verified {
            await sessionManager.refreshUser()
            await sessionManager.refreshProfile()
        } else {
            errorMessage = result.failureReason ?? "Very verification was not completed."
        }
    }

    private func refreshSession() async {
        guard let id = session?.id else { return }
        isLoading = true
        errorMessage = nil
        do {
            let refreshed = try await ApiClient.shared.verificationSession(id: id)
            session = refreshed
            if refreshed.status == "verified" {
                await sessionManager.refreshProfile()
            }
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func openLaunchURL(for session: VerificationSession) {
        guard let rawURL = launchURL(from: session), let url = URL(string: rawURL) else {
            if provider == "very" {
                errorMessage = "Very launch data was not returned yet. Install VeryAI from the App Store, then try again."
                openMobileAppStore()
            }
            return
        }
        openURL(url) { accepted in
            if !accepted {
                if provider == "very" {
                    errorMessage = "Could not open VeryAI. Install it from the App Store, then try again."
                    openMobileAppStore()
                } else {
                    errorMessage = "Could not open verification."
                }
            }
        }
    }

    private func statusTitle(for session: VerificationSession) -> String {
        switch session.status {
        case "verified":
            return "Verified"
        case "failed":
            return "Verification failed"
        case "expired":
            return "Session expired"
        default:
            return provider == "very" ? "Finish your palm scan" : "Verification pending"
        }
    }

    private func statusDescription(for session: VerificationSession) -> String {
        switch session.status {
        case "verified":
            return "You're verified. New onboarding tasks should clear after notifications refresh."
        case "failed":
            return "Start a new verification session and try again."
        case "expired":
            return "This verification session expired. Start a new one to continue."
        default:
            return provider == "very"
                ? "Complete the palm scan, then Pirate will verify the signed result."
                : "Complete the provider flow, then return here and check status."
        }
    }

    private var mobileAppDownload: VerificationMobileAppDownload? {
        switch provider {
        case "very":
            return nil
        case "self":
            return VerificationMobileAppDownload(
                appName: "Self",
                iosURL: URL(string: "https://apps.apple.com/us/app/self-zk-passport-identity/id6478563710")
            )
        default:
            return nil
        }
    }

    private func appDownloadSection(_ download: VerificationMobileAppDownload) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(colors.borderSoft)
                    .frame(height: 1)
                Text("Need the \(download.appName) app?")
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
                Rectangle()
                    .fill(colors.borderSoft)
                    .frame(height: 1)
            }

            if let iosURL = download.iosURL {
                Link(destination: iosURL) {
                    verificationOutlineButtonLabel("App Store")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func startErrorMessage(for error: ApiError) -> String {
        guard provider == "very", shouldOpenInstallFallback(for: error) else {
            return error.displayMessage
        }
        return "We could not start VeryAI from Pirate yet. Install VeryAI from the App Store, then try again."
    }

    private func shouldOpenInstallFallback(for error: ApiError) -> Bool {
        guard provider == "very", !error.isAuthError else { return false }
        guard case .serverError(let statusCode, _, let code, _, _) = error else { return false }
        return code == "internal_error" || code == "provider_unavailable" || statusCode == 501 || statusCode == 502
    }

    private func openMobileAppStore() {
        guard let url = mobileAppDownload?.iosURL else { return }
        openURL(url)
    }

    private func verificationButtonLabel(_ title: String, loading: Bool) -> some View {
        HStack {
            if loading { ProgressView().tint(colors.textOnAccent) }
            Text(title)
        }
        .font(PirateTokens.Typography.bodyStrong)
        .foregroundStyle(colors.textOnAccent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
    }

    private func verificationOutlineButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(PirateTokens.Typography.bodyStrong)
            .foregroundStyle(colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.full))
            .overlay(
                RoundedRectangle(cornerRadius: radii.full)
                    .stroke(colors.borderDefault, lineWidth: 1)
            )
    }

    private func launchURL(from session: VerificationSession) -> String? {
        guard let launch = session.launch else { return nil }
        let keys = provider == "very"
            ? ["deeplink_url", "deeplinkUrl", "deep_link", "deepLink", "app_url", "appUrl", "launch_url", "launchUrl", "universal_link", "universalLink", "url", "href"]
            : ["verify_url", "verifyUrl", "deeplink_callback", "deeplinkCallback", "url", "href"]
        for key in keys {
            if let match = launch.firstStringValue(named: key) {
                return match
            }
        }
        return nil
    }

    private func launchMode(from session: VerificationSession) -> String? {
        guard let launch = session.launch else { return nil }
        return launch.firstStringValue(named: "mode")
    }
}

private struct VerificationMobileAppDownload {
    let appName: String
    let iosURL: URL?
}
