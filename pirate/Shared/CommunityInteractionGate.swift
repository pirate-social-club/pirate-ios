import Observation
import SwiftUI

enum CommunityInteractionGateKind: Equatable {
    case joinToVote
    case proveAndJoinToVote
    case verifyToVote(provider: String)
    case passportToVote
    case pending
    case blocked
    case error
}

struct CommunityInteractionGateSheetState: Identifiable {
    let id = UUID()
    let kind: CommunityInteractionGateKind
    let communityId: String
    let communityName: String
    var title: String
    var message: String
    var primaryTitle: String?
    var secondaryTitle: String?
    var requirements: [MembershipGateSummary]
    var isWorking = false
    var route: PirateRoute?
    var externalURL: URL?
    var selfRequestedCapabilities: [String] = ["unique_human"]
    var selfVerificationRequirements: [VerificationRequirement] = []
}

struct SelfVerificationSheetRequest: Identifiable {
    let id = UUID()
    let intent: String
    let requestedCapabilities: [String]
    let verificationRequirements: [VerificationRequirement]
}

private struct PendingPostVote {
    let communityId: String
    let communityName: String
    let postId: String
    let value: Int
    let perform: (String) async throws -> Void
}

@MainActor
@Observable
final class CommunityInteractionGateController {
    var sheetState: CommunityInteractionGateSheetState?
    var inlineError: String?

    private var eligibilityCache: [String: JoinEligibility] = [:]
    private var eligibilityTasks: [String: Task<JoinEligibility, Error>] = [:]
    private var cacheUserId: String?
    private var pendingPostVote: PendingPostVote?
    private var solverTask: Task<Void, Never>?

    var isSheetPresented: Bool {
        sheetState != nil
    }

    func closeSheet() {
        solverTask?.cancel()
        solverTask = nil
        sheetState = nil
    }

    func resetCacheIfNeeded(userId: String?) {
        if cacheUserId != userId {
            eligibilityCache = [:]
            eligibilityTasks.values.forEach { $0.cancel() }
            eligibilityTasks = [:]
            cacheUserId = userId
        }
    }

    func prewarmEligibility(
        communityIds: [String],
        isAuthenticated: Bool,
        userId: String?,
        limit: Int = 10,
        maxConcurrent: Int = 3
    ) async {
        guard isAuthenticated else { return }
        resetCacheIfNeeded(userId: userId)
        let uniqueIds = Array(NSOrderedSet(array: communityIds).compactMap { $0 as? String })
            .filter { !$0.isEmpty && eligibilityCache[$0] == nil && eligibilityTasks[$0] == nil }
            .prefix(limit)
        guard !uniqueIds.isEmpty else { return }

        let scheduledTasks = uniqueIds.map { communityId in
            (communityId, eligibilityTask(for: communityId))
        }
        var iterator = scheduledTasks.makeIterator()
        await withTaskGroup(of: (String, Result<JoinEligibility, Error>).self) { group in
            for _ in 0..<maxConcurrent {
                guard let (communityId, task) = iterator.next() else { break }
                group.addTask {
                    do {
                        return (communityId, .success(try await task.value))
                    } catch {
                        return (communityId, .failure(error))
                    }
                }
            }

            while let result = await group.next() {
                let (communityId, outcome) = result
                eligibilityTasks[communityId] = nil
                if case .success(let eligibility) = outcome {
                    eligibilityCache[communityId] = eligibility
                }
                if let (nextCommunityId, task) = iterator.next() {
                    group.addTask {
                        do {
                            return (nextCommunityId, .success(try await task.value))
                        } catch {
                            return (nextCommunityId, .failure(error))
                        }
                    }
                }
            }
        }
    }

    func runPostVote(
        isAuthenticated: Bool,
        userId: String?,
        communityId: String,
        communityName: String,
        postId: String,
        value: Int,
        showSignIn: () -> Void,
        perform: @escaping (String) async throws -> Void
    ) async {
        guard value == 1 || value == -1 else { return }
        guard isAuthenticated else {
            showSignIn()
            return
        }

        resetCacheIfNeeded(userId: userId)
        inlineError = nil
        pendingPostVote = PendingPostVote(
            communityId: communityId,
            communityName: communityName,
            postId: postId,
            value: value,
            perform: perform
        )
        await continuePendingPostVote()
    }

    func resumeWithRetry(maxAttempts: Int = 3, intervalSeconds: Double = 1.5) async {
        guard pendingPostVote != nil else { return }
        for attempt in 0..<maxAttempts {
            await invalidatePendingCommunityEligibility()
            await continuePendingPostVote(isResumeAttempt: true)
            if pendingPostVote == nil { return }
            // Verification callbacks can arrive before the backend has finished updating eligibility.
            if case .verifyToVote? = sheetState?.kind, attempt < maxAttempts - 1 {
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
                continue
            }
            return
        }
    }

    func performPrimaryAction() {
        switch sheetState?.kind {
        case .joinToVote:
            solverTask = Task { await joinThenVote(needsJoinAltcha: false) }
        case .proveAndJoinToVote:
            solverTask = Task { await joinThenVote(needsJoinAltcha: true) }
        case .passportToVote:
            break
        case .error:
            solverTask = Task { await continuePendingPostVote() }
        default:
            break
        }
    }

    func solvePostVotePayload(postId: String, value: Int) async throws -> String {
        let postRef = publicPostRef(postId)
        return try await solveAltcha(scope: "vote", action: "post:\(postRef):\(value)")
    }

    func solveCommentVotePayload(commentId: String, value: Int) async throws -> String {
        let commentRef = publicCommentRef(commentId)
        return try await solveAltcha(scope: "vote", action: "comment:\(commentRef):\(value)")
    }

    private func continuePendingPostVote(isResumeAttempt: Bool = false) async {
        guard let pending = pendingPostVote else { return }
        setWorking(true)

        do {
            let eligibility = try await eligibility(for: pending.communityId)
            setWorking(false)
            switch eligibility.status {
            case "already_joined":
                await voteWithProof()
            case "joinable":
                presentJoinSheet(eligibility: eligibility)
            case "verification_required":
                presentVerificationSheet(eligibility: eligibility)
            case "requestable":
                presentBlockedSheet(
                    eligibility: eligibility,
                    title: "Request to join",
                    message: "Request to join \(pending.communityName) before you vote."
                )
            case "pending_request":
                presentBlockedSheet(
                    eligibility: eligibility,
                    title: "Request pending",
                    message: "Your join request is still pending."
                )
            case "banned":
                presentBlockedSheet(
                    eligibility: eligibility,
                    title: "Can't vote here",
                    message: "This account cannot join \(pending.communityName)."
                )
            default:
                presentBlockedSheet(
                    eligibility: eligibility,
                    title: "Can't vote here",
                    message: eligibility.failureReason ?? "You do not meet this community's requirements."
                )
            }
        } catch let error as ApiError {
            setWorking(false)
            presentError(message: error.displayMessage)
        } catch {
            setWorking(false)
            presentError(message: error.localizedDescription)
        }
    }

    private func eligibility(for communityId: String) async throws -> JoinEligibility {
        if let cached = eligibilityCache[communityId] {
            return cached
        }
        let task = eligibilityTask(for: communityId)
        do {
            let eligibility = try await task.value
            eligibilityCache[communityId] = eligibility
            eligibilityTasks[communityId] = nil
            return eligibility
        } catch {
            eligibilityTasks[communityId] = nil
            throw error
        }
    }

    private func eligibilityTask(for communityId: String) -> Task<JoinEligibility, Error> {
        if let existingTask = eligibilityTasks[communityId] {
            return existingTask
        }
        let task = Task {
            try await ApiClient.shared.joinEligibility(communityId: communityId)
        }
        eligibilityTasks[communityId] = task
        return task
    }

    private func invalidatePendingCommunityEligibility() async {
        guard let pending = pendingPostVote else { return }
        eligibilityCache[pending.communityId] = nil
    }

    private func presentJoinSheet(eligibility: JoinEligibility) {
        guard let pending = pendingPostVote else { return }
        sheetState = CommunityInteractionGateSheetState(
            kind: .joinToVote,
            communityId: pending.communityId,
            communityName: pending.communityName,
            title: "Join to vote",
            message: "Join \(pending.communityName) before you vote.",
            primaryTitle: "Join and vote",
            secondaryTitle: "Cancel",
            requirements: eligibility.membershipGateSummaries ?? []
        )
    }

    private func presentVerificationSheet(eligibility: JoinEligibility) {
        guard let pending = pendingPostVote else { return }
        let provider = verificationProvider(for: eligibility)
        let requirements = eligibility.membershipGateSummaries ?? []

        if missingCapabilities(eligibility).contains("altcha_pow") || provider == "altcha" {
            sheetState = CommunityInteractionGateSheetState(
                kind: .proveAndJoinToVote,
                communityId: pending.communityId,
                communityName: pending.communityName,
                title: "Check device",
                message: "This community requires a proof-of-work check before joining.",
                primaryTitle: "Continue",
                secondaryTitle: "Cancel",
                requirements: requirements
            )
            return
        }

        if provider == "passport" {
            sheetState = CommunityInteractionGateSheetState(
                kind: .passportToVote,
                communityId: pending.communityId,
                communityName: pending.communityName,
                title: "Improve wallet score",
                message: "Your wallet lacks meaningful history, so we cannot confirm you're human.",
                primaryTitle: "Improve Score",
                secondaryTitle: "Cancel",
                requirements: requirements,
                externalURL: URL(string: "https://app.passport.xyz/")
            )
            return
        }

        let route: PirateRoute = provider == "very"
            ? .verificationVery(eligibility.suggestedVerificationIntent ?? "community_join")
            : .verificationSelf(eligibility.suggestedVerificationIntent ?? "community_join")
        sheetState = CommunityInteractionGateSheetState(
            kind: .verifyToVote(provider: provider ?? "self"),
            communityId: pending.communityId,
            communityName: pending.communityName,
            title: "Verify to vote",
            message: "Complete verification, then return here to finish your vote.",
            primaryTitle: provider == "very" ? "Verify with Very" : "Verify with ID",
            secondaryTitle: "Cancel",
            requirements: requirements,
            route: route,
            selfRequestedCapabilities: selfRequestedCapabilities(for: eligibility),
            selfVerificationRequirements: verificationRequirements(for: eligibility.membershipGateSummaries)
        )
    }

    private func presentBlockedSheet(eligibility: JoinEligibility, title: String, message: String) {
        guard let pending = pendingPostVote else { return }
        sheetState = CommunityInteractionGateSheetState(
            kind: eligibility.status == "pending_request" ? .pending : .blocked,
            communityId: pending.communityId,
            communityName: pending.communityName,
            title: title,
            message: message,
            primaryTitle: nil,
            secondaryTitle: "Close",
            requirements: eligibility.membershipGateSummaries ?? []
        )
    }

    private func presentError(message: String) {
        guard let pending = pendingPostVote else {
            inlineError = message
            return
        }
        sheetState = CommunityInteractionGateSheetState(
            kind: .error,
            communityId: pending.communityId,
            communityName: pending.communityName,
            title: "Could not check requirements",
            message: message,
            primaryTitle: "Try again",
            secondaryTitle: "Cancel",
            requirements: []
        )
    }

    private func joinThenVote(needsJoinAltcha: Bool) async {
        guard let pending = pendingPostVote else { return }
        setWorking(true)
        do {
            let eligibility = try await eligibility(for: pending.communityId)
            let communityRef = publicCommunityRef(eligibility: eligibility, fallback: pending.communityId)
            let joinPayload = needsJoinAltcha
                ? try await solveAltcha(scope: "community_join", action: "community:\(communityRef)")
                : nil
            _ = try await ApiClient.shared.joinCommunity(
                communityId: pending.communityId,
                altchaPayload: joinPayload
            )
            eligibilityCache[pending.communityId] = nil
            setWorking(false)
            await voteWithProof()
        } catch let error as ApiError {
            setWorking(false)
            presentError(message: error.displayMessage)
        } catch {
            setWorking(false)
            presentError(message: error.localizedDescription)
        }
    }

    private func voteWithProof() async {
        guard let pending = pendingPostVote else { return }
        setWorking(true)
        do {
            let payload = try await solvePostVotePayload(postId: pending.postId, value: pending.value)
            try await pending.perform(payload)
            eligibilityCache[pending.communityId] = nil
            pendingPostVote = nil
            setWorking(false)
            sheetState = nil
        } catch let error as ApiError {
            setWorking(false)
            if error.code == "gate_failed" {
                eligibilityCache[pending.communityId] = nil
                await continuePendingPostVote()
            } else {
                presentError(message: error.displayMessage)
            }
        } catch {
            setWorking(false)
            presentError(message: error.localizedDescription)
        }
    }

    private func refreshPassportAndRetry() async {
        guard let pending = pendingPostVote else { return }
        setWorking(true)
        do {
            let response = try await ApiClient.shared.refreshPassportWalletScore(communityId: pending.communityId)
            if let eligibility = response.joinEligibility {
                eligibilityCache[pending.communityId] = eligibility
            } else {
                eligibilityCache[pending.communityId] = nil
            }
            setWorking(false)
            await continuePendingPostVote()
        } catch let error as ApiError {
            setWorking(false)
            presentError(message: error.displayMessage)
        } catch {
            setWorking(false)
            presentError(message: error.localizedDescription)
        }
    }

    private func solveAltcha(scope: String, action: String) async throws -> String {
        let challenge = try await ApiClient.shared.createAltchaChallenge(scope: scope, action: action)
        let solved = try await AltchaSolver.solve(challenge)
        return solved.payload
    }

    private func setWorking(_ isWorking: Bool) {
        guard var state = sheetState else { return }
        state.isWorking = isWorking
        sheetState = state
    }

    private func verificationProvider(for eligibility: JoinEligibility) -> String? {
        let provider = eligibility.suggestedVerificationProvider ?? eligibility.humanVerificationLane
        guard let normalized = provider?.lowercased() else { return nil }
        if normalized.contains("very") { return "very" }
        if normalized.contains("passport") || normalized.contains("wallet_score") { return "passport" }
        if normalized.contains("altcha") { return "altcha" }
        if normalized.contains("self") { return "self" }
        return normalized
    }

    private func missingCapabilities(_ eligibility: JoinEligibility) -> [String] {
        eligibility.missingCapabilities ?? []
    }

    private func selfRequestedCapabilities(for eligibility: JoinEligibility) -> [String] {
        let order = ["unique_human", "age_over_18", "nationality", "gender"]
        let missing = Set(missingCapabilities(eligibility))
        let capabilities = order.filter { missing.contains($0) }
        return capabilities.isEmpty ? ["unique_human"] : capabilities
    }

    private func verificationRequirements(for summaries: [MembershipGateSummary]?) -> [VerificationRequirement] {
        var requirements: [VerificationRequirement] = []
        let ages = (summaries ?? []).compactMap { gate -> Int? in
            gate.gateType == "minimum_age" ? gate.requiredMinimumAge : nil
        }
        if let minimumAge = ages.max() {
            requirements.append(VerificationRequirement(proofType: "minimum_age", minimumAge: minimumAge))
        }

        let nationalities = Set((summaries ?? []).flatMap { gate -> [String] in
            guard gate.gateType == "nationality" else { return [] }
            let values = gate.requiredValues ?? gate.requiredValue.map { [$0] } ?? []
            return values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }.filter { !$0.isEmpty }
        })
        if !nationalities.isEmpty {
            requirements.append(VerificationRequirement(proofType: "nationality", requiredValues: Array(nationalities).sorted()))
        }
        return requirements
    }

    private func publicCommunityRef(eligibility: JoinEligibility, fallback: String) -> String {
        let candidate = eligibility.communityId.isEmpty ? fallback : eligibility.communityId
        return candidate.hasPrefix("com_") ? candidate : "com_\(candidate)"
    }

    private func publicPostRef(_ postId: String) -> String {
        postId.hasPrefix("post_") ? postId : "post_\(postId)"
    }

    private func publicCommentRef(_ commentId: String) -> String {
        commentId.hasPrefix("cmt_") ? commentId : "cmt_\(commentId)"
    }
}

struct CommunityInteractionGateSheet: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    @Environment(\.openURL) private var openURL
    @Bindable var controller: CommunityInteractionGateController
    var onSelfVerificationRequested: ((SelfVerificationSheetRequest) -> Void)?

    init(
        controller: CommunityInteractionGateController,
        onSelfVerificationRequested: ((SelfVerificationSheetRequest) -> Void)? = nil
    ) {
        self.controller = controller
        self.onSelfVerificationRequested = onSelfVerificationRequested
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let state = controller.sheetState {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(state.title)
                                .font(PirateTokens.Typography.h3)
                                .foregroundStyle(colors.textPrimary)
                            Text(state.message)
                                .font(PirateTokens.Typography.body)
                                .foregroundStyle(colors.textSecondary)
                        }
                        Spacer()
                        Button {
                            controller.closeSheet()
                        } label: {
                            PirateIconView(icon: .x, size: 16, color: colors.textSecondary)
                                .frame(width: 34, height: 34)
                                .background(colors.surfaceSubtle, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    if !state.requirements.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Requirements")
                                .font(PirateTokens.Typography.smallStrong)
                                .foregroundStyle(colors.textSecondary)
                            ForEach(Array(state.requirements.enumerated()), id: \.offset) { _, requirement in
                                HStack(spacing: 10) {
                                    PirateIconView(icon: .check, size: 18, color: colors.textSecondary)
                                    Text(label(for: requirement))
                                        .font(PirateTokens.Typography.body)
                                        .foregroundStyle(colors.textPrimary)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(14)
                        .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.md))
                    }

                    VStack(spacing: 10) {
                        if let route = state.route,
                           case .verificationSelf(let intent) = route,
                           let title = state.primaryTitle,
                           let onSelfVerificationRequested {
                            Button {
                                controller.closeSheet()
                                onSelfVerificationRequested(SelfVerificationSheetRequest(
                                    intent: intent,
                                    requestedCapabilities: state.selfRequestedCapabilities,
                                    verificationRequirements: state.selfVerificationRequirements
                                ))
                            } label: {
                                primaryLabel(title, isWorking: state.isWorking)
                            }
                            .buttonStyle(.plain)
                            .disabled(state.isWorking)
                        } else if let route = state.route, let title = state.primaryTitle {
                            NavigationLink(value: route) {
                                primaryLabel(title, isWorking: state.isWorking)
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                controller.closeSheet()
                            })
                            .buttonStyle(.plain)
                        } else if let externalURL = state.externalURL, let title = state.primaryTitle {
                            Button {
                                openURL(externalURL)
                                controller.closeSheet()
                            } label: {
                                primaryLabel(title, isWorking: state.isWorking)
                            }
                            .buttonStyle(.plain)
                            .disabled(state.isWorking)
                        } else if let title = state.primaryTitle {
                            Button {
                                controller.performPrimaryAction()
                            } label: {
                                primaryLabel(title, isWorking: state.isWorking)
                            }
                            .buttonStyle(.plain)
                            .disabled(state.isWorking)
                        }

                        if let title = state.secondaryTitle {
                            Button {
                                controller.closeSheet()
                            } label: {
                                Text(title)
                                    .font(PirateTokens.Typography.bodyStrong)
                                    .foregroundStyle(colors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .disabled(state.isWorking)
                        }
                    }
                }
            }
            .padding(PirateTokens.pageGutter)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(colors.bgPage)
    }

    private func primaryLabel(_ title: String, isWorking: Bool) -> some View {
        HStack {
            if isWorking {
                ProgressView().tint(colors.textOnAccent)
            }
            Text(isWorking ? "Checking..." : title)
        }
        .font(PirateTokens.Typography.bodyStrong)
        .foregroundStyle(colors.textOnAccent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
    }

    private func label(for requirement: MembershipGateSummary) -> String {
        switch requirement.gateType {
        case "altcha_pow":
            return "Proof-of-work check"
        case "wallet_score", "passport_score":
            if let score = requirement.minimumScore {
                return "Wallet score \(Int(score))+"
            }
            return "Wallet score"
        case "unique_human":
            return "Unique human verification"
        case "minimum_age", "age_over_18":
            return "Age \(requirement.requiredMinimumAge ?? 18)+"
        case "nationality":
            let values = requirement.requiredValues ?? requirement.requiredValue.map { [$0] } ?? []
            return values.isEmpty ? "Nationality requirement" : "Nationality: \(values.joined(separator: ", "))"
        case "gender":
            let values = requirement.requiredValues ?? requirement.requiredValue.map { [$0] } ?? []
            return values.isEmpty ? "Gender requirement" : "Gender: \(values.joined(separator: ", "))"
        case "erc721_holding", "erc721_inventory_match":
            return requirement.assetFilterLabel ?? "Collectible ownership"
        default:
            return (requirement.gateType ?? "Requirement").replacingOccurrences(of: "_", with: " ")
        }
    }
}
