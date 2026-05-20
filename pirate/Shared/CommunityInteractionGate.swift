import Observation
import SwiftUI

enum CommunityInteractionGateKind: Equatable {
    case joinCommunity
    case proveAndJoinCommunity
    case joinToPost
    case proveAndJoinToPost
    case joinToReply
    case proveAndJoinToReply
    case joinToVote
    case proveAndJoinToVote
    case proveAndVote
    case verifyToVote(provider: String)
    case verifyToReply(provider: String)
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

private struct PendingPostCompose {
    let communityId: String
    let communityName: String
    let continueAfterJoin: @MainActor () -> Void
}

private struct PendingPostReplyAccess {
    let communityId: String
    let communityName: String
    let continueAfterAccess: @MainActor () -> Void
}

private struct PendingCommunityJoin {
    let communityId: String
    let communityName: String
    let didJoin: @MainActor () -> Void
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
    private var pendingPostCompose: PendingPostCompose?
    private var pendingPostReplyAccess: PendingPostReplyAccess?
    private var pendingCommunityJoin: PendingCommunityJoin?
    private var solverTask: Task<Void, Never>?

    var isSheetPresented: Bool {
        sheetState != nil
    }

    func closeSheet() {
        solverTask?.cancel()
        solverTask = nil
        pendingPostVote = nil
        pendingPostCompose = nil
        pendingPostReplyAccess = nil
        pendingCommunityJoin = nil
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

    func runPostCompose(
        isAuthenticated: Bool,
        userId: String?,
        communityId: String,
        communityName: String,
        showSignIn: () -> Void,
        continueAfterJoin: @escaping @MainActor () -> Void
    ) async {
        guard isAuthenticated else {
            showSignIn()
            return
        }

        resetCacheIfNeeded(userId: userId)
        inlineError = nil
        pendingPostCompose = PendingPostCompose(
            communityId: communityId,
            communityName: communityName,
            continueAfterJoin: continueAfterJoin
        )
        await continuePendingPostCompose()
    }

    func runPostReplyAccess(
        isAuthenticated: Bool,
        userId: String?,
        communityId: String,
        communityName: String,
        showSignIn: () -> Void,
        continueAfterAccess: @escaping @MainActor () -> Void
    ) async {
        guard isAuthenticated else {
            showSignIn()
            return
        }

        resetCacheIfNeeded(userId: userId)
        inlineError = nil
        pendingPostReplyAccess = PendingPostReplyAccess(
            communityId: communityId,
            communityName: communityName,
            continueAfterAccess: continueAfterAccess
        )
        await continuePendingPostReplyAccess()
    }

    func runCommunityJoin(
        isAuthenticated: Bool,
        userId: String?,
        communityId: String,
        communityName: String,
        showSignIn: () -> Void,
        didJoin: @escaping @MainActor () -> Void
    ) async {
        guard isAuthenticated else {
            showSignIn()
            return
        }

        resetCacheIfNeeded(userId: userId)
        inlineError = nil
        pendingCommunityJoin = PendingCommunityJoin(
            communityId: communityId,
            communityName: communityName,
            didJoin: didJoin
        )
        await continuePendingCommunityJoin()
    }

    func resumeWithRetry(maxAttempts: Int = 3, intervalSeconds: Double = 1.5) async {
        if pendingCommunityJoin != nil {
            await invalidatePendingCommunityJoinEligibility()
            await continuePendingCommunityJoin()
            return
        }

        if pendingPostCompose != nil {
            await invalidatePendingComposeEligibility()
            await continuePendingPostCompose()
            return
        }

        if pendingPostReplyAccess != nil {
            await invalidatePendingReplyAccessEligibility()
            await continuePendingPostReplyAccess()
            return
        }

        guard pendingPostVote != nil else { return }
        for attempt in 0..<maxAttempts {
            await invalidatePendingCommunityEligibility()
            await continuePendingPostVote(isResumeAttempt: true)
            if pendingPostVote == nil { return }
            // Verification callbacks can arrive before the backend has finished updating eligibility.
            if isVerificationSheetActive, attempt < maxAttempts - 1 {
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
                continue
            }
            return
        }
    }

    func performPrimaryAction() {
        switch sheetState?.kind {
        case .joinCommunity:
            solverTask = Task { await joinCommunityFromSheet(needsJoinAltcha: false) }
        case .proveAndJoinCommunity:
            solverTask = Task { await joinCommunityFromSheet(needsJoinAltcha: true) }
        case .joinToPost:
            solverTask = Task { await joinThenCompose(needsJoinAltcha: false) }
        case .proveAndJoinToPost:
            solverTask = Task { await joinThenCompose(needsJoinAltcha: true) }
        case .joinToReply:
            solverTask = Task { await joinThenReply(needsJoinAltcha: false) }
        case .proveAndJoinToReply:
            solverTask = Task { await joinThenReply(needsJoinAltcha: true) }
        case .joinToVote:
            solverTask = Task { await joinThenVote(needsJoinAltcha: false) }
        case .proveAndJoinToVote:
            solverTask = Task { await joinThenVote(needsJoinAltcha: true) }
        case .proveAndVote:
            break
        case .passportToVote:
            break
        case .error:
            if pendingCommunityJoin != nil {
            solverTask = Task { await continuePendingCommunityJoin() }
        } else if pendingPostCompose != nil {
            solverTask = Task { await continuePendingPostCompose() }
        } else if pendingPostReplyAccess != nil {
            solverTask = Task { await continuePendingPostReplyAccess() }
        } else {
            solverTask = Task { await continuePendingPostVote() }
        }
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

    func solvePostCommentPayload(postId: String) async throws -> String {
        let postRef = publicPostRef(postId)
        return try await solveAltcha(scope: "comment_create", action: "post:\(postRef)")
    }

    func solveCommentReplyPayload(commentId: String) async throws -> String {
        let commentRef = publicCommentRef(commentId)
        return try await solveAltcha(scope: "comment_create", action: "comment:\(commentRef)")
    }

    func communityRequiresProofOfWork(
        communityId: String,
        isAuthenticated: Bool,
        userId: String?
    ) async -> Bool {
        guard isAuthenticated else { return false }
        resetCacheIfNeeded(userId: userId)
        guard let eligibility = try? await eligibility(for: communityId) else { return false }
        return hasProofOfWorkGate(eligibility)
    }

    func runCommentVote(
        isAuthenticated: Bool,
        communityId: String,
        communityName: String,
        commentId: String,
        value: Int,
        showSignIn: () -> Void,
        perform: @escaping (String) async throws -> Void
    ) async {
        guard value == 1 || value == -1 else { return }
        guard isAuthenticated else {
            showSignIn()
            return
        }

        inlineError = nil
        presentVoteProgress(communityId: communityId, communityName: communityName, value: value)
        do {
            let payload = try await solveCommentVotePayload(commentId: commentId, value: value)
            guard sheetState != nil else { return }
            try await perform(payload)
            sheetState = nil
        } catch let error as ApiError {
            sheetState = nil
            inlineError = error.displayMessage
        } catch {
            sheetState = nil
            inlineError = error.localizedDescription
        }
    }

    func runStandalonePostVote(
        isAuthenticated: Bool,
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

        inlineError = nil
        presentVoteProgress(communityId: communityId, communityName: communityName, value: value)
        do {
            let payload = try await solvePostVotePayload(postId: postId, value: value)
            guard sheetState != nil else { return }
            try await perform(payload)
            sheetState = nil
        } catch let error as ApiError {
            sheetState = nil
            inlineError = error.displayMessage
        } catch {
            sheetState = nil
            inlineError = error.localizedDescription
        }
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
                await joinThenVote(needsJoinAltcha: false)
            case "verification_required":
                if isProofOfWorkOnly(eligibility) {
                    await joinThenVote(needsJoinAltcha: true)
                } else {
                    presentVerificationSheet(eligibility: eligibility)
                }
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

    private func continuePendingPostCompose() async {
        guard let pending = pendingPostCompose else { return }
        setWorking(true)

        do {
            let eligibility = try await eligibility(for: pending.communityId)
            setWorking(false)
            switch eligibility.status {
            case "already_joined":
                pendingPostCompose = nil
                sheetState = nil
                pending.continueAfterJoin()
            case "joinable":
                await joinThenCompose(needsJoinAltcha: false)
            case "verification_required":
                if isProofOfWorkOnly(eligibility) {
                    await joinThenCompose(needsJoinAltcha: true)
                } else {
                    presentPostVerificationSheet(eligibility: eligibility)
                }
            case "requestable":
                presentPostBlockedSheet(
                    eligibility: eligibility,
                    title: "Request to join",
                    message: "Request to join \(pending.communityName) before you post."
                )
            case "pending_request":
                presentPostBlockedSheet(
                    eligibility: eligibility,
                    title: "Request pending",
                    message: "Your join request is still pending."
                )
            case "banned":
                presentPostBlockedSheet(
                    eligibility: eligibility,
                    title: "Can't post here",
                    message: "This account cannot join \(pending.communityName)."
                )
            default:
                presentPostBlockedSheet(
                    eligibility: eligibility,
                    title: "Can't post here",
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

    private func continuePendingPostReplyAccess() async {
        guard let pending = pendingPostReplyAccess else { return }
        setWorking(true)

        do {
            let eligibility = try await eligibility(for: pending.communityId)
            setWorking(false)
            switch eligibility.status {
            case "already_joined":
                pendingPostReplyAccess = nil
                sheetState = nil
                pending.continueAfterAccess()
            case "joinable":
                await joinThenReply(needsJoinAltcha: false)
            case "verification_required":
                if isProofOfWorkOnly(eligibility) {
                    await joinThenReply(needsJoinAltcha: true)
                } else {
                    presentReplyVerificationSheet(eligibility: eligibility)
                }
            case "requestable":
                presentReplyBlockedSheet(
                    eligibility: eligibility,
                    title: "Request to join",
                    message: "Request to join \(pending.communityName) before you comment."
                )
            case "pending_request":
                presentReplyBlockedSheet(
                    eligibility: eligibility,
                    title: "Request pending",
                    message: "Your join request is still pending."
                )
            case "banned":
                presentReplyBlockedSheet(
                    eligibility: eligibility,
                    title: "Can't comment here",
                    message: "This account cannot join \(pending.communityName)."
                )
            default:
                presentReplyBlockedSheet(
                    eligibility: eligibility,
                    title: "Can't comment here",
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

    private func continuePendingCommunityJoin() async {
        guard let pending = pendingCommunityJoin else { return }
        setWorking(true)

        do {
            let eligibility = try await eligibility(for: pending.communityId)
            setWorking(false)
            switch eligibility.status {
            case "already_joined":
                pendingCommunityJoin = nil
                sheetState = nil
                pending.didJoin()
            case "joinable":
                await joinCommunityFromSheet(needsJoinAltcha: false)
            case "verification_required":
                if isProofOfWorkOnly(eligibility) {
                    await joinCommunityFromSheet(needsJoinAltcha: true)
                } else {
                    presentCommunityVerificationSheet(eligibility: eligibility)
                }
            case "requestable":
                presentCommunityBlockedSheet(
                    eligibility: eligibility,
                    title: "Request to join",
                    message: "Request to join \(pending.communityName)."
                )
            case "pending_request":
                presentCommunityBlockedSheet(
                    eligibility: eligibility,
                    title: "Request pending",
                    message: "Your join request is still pending."
                )
            case "banned":
                presentCommunityBlockedSheet(
                    eligibility: eligibility,
                    title: "Can't join",
                    message: "This account cannot join \(pending.communityName)."
                )
            default:
                presentCommunityBlockedSheet(
                    eligibility: eligibility,
                    title: "Can't join",
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

    private func invalidatePendingComposeEligibility() async {
        guard let pending = pendingPostCompose else { return }
        eligibilityCache[pending.communityId] = nil
    }

    private func invalidatePendingReplyAccessEligibility() async {
        guard let pending = pendingPostReplyAccess else { return }
        eligibilityCache[pending.communityId] = nil
    }

    private func invalidatePendingCommunityJoinEligibility() async {
        guard let pending = pendingCommunityJoin else { return }
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
            primaryTitle: "Join",
            secondaryTitle: "Cancel",
            requirements: eligibility.membershipGateSummaries ?? []
        )
    }

    private func presentCommunityJoinSheet(eligibility: JoinEligibility) {
        guard let pending = pendingCommunityJoin else { return }
        sheetState = CommunityInteractionGateSheetState(
            kind: .joinCommunity,
            communityId: pending.communityId,
            communityName: pending.communityName,
            title: "Join \(pending.communityName)",
            message: "Join this community.",
            primaryTitle: "Join",
            secondaryTitle: "Cancel",
            requirements: eligibility.membershipGateSummaries ?? []
        )
    }

    private func presentCommunityVerificationSheet(eligibility: JoinEligibility) {
        guard let pending = pendingCommunityJoin else { return }
        let provider = verificationProvider(for: eligibility)
        let requirements = eligibility.membershipGateSummaries ?? []

        if missingCapabilities(eligibility).contains("altcha_pow") || provider == "altcha" {
            sheetState = CommunityInteractionGateSheetState(
                kind: .proveAndJoinCommunity,
                communityId: pending.communityId,
                communityName: pending.communityName,
                title: "Join \(pending.communityName)",
                message: "Join this community.",
                primaryTitle: "Join",
                secondaryTitle: "Cancel",
                requirements: requirements
            )
            return
        }

        if provider == "token" {
            presentCommunityBlockedSheet(
                eligibility: eligibility,
                title: "Can't join",
                message: tokenGateMessage(eligibility: eligibility, action: "join")
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
            title: "Verify to join",
            message: "Complete verification, then return here to join.",
            primaryTitle: provider == "very" ? "Verify with Very" : "Verify with ID",
            secondaryTitle: "Cancel",
            requirements: requirements,
            route: route,
            selfRequestedCapabilities: selfRequestedCapabilities(for: eligibility),
            selfVerificationRequirements: verificationRequirements(for: eligibility.membershipGateSummaries)
        )
    }

    private func presentPostJoinSheet(eligibility: JoinEligibility) {
        guard let pending = pendingPostCompose else { return }
        sheetState = CommunityInteractionGateSheetState(
            kind: .joinToPost,
            communityId: pending.communityId,
            communityName: pending.communityName,
            title: "Join \(pending.communityName)",
            message: "Join this community before you post.",
            primaryTitle: "Join",
            secondaryTitle: "Cancel",
            requirements: eligibility.membershipGateSummaries ?? []
        )
    }

    private func presentPostVerificationSheet(eligibility: JoinEligibility) {
        guard let pending = pendingPostCompose else { return }
        let provider = verificationProvider(for: eligibility)
        let requirements = eligibility.membershipGateSummaries ?? []

        if missingCapabilities(eligibility).contains("altcha_pow") || provider == "altcha" {
            sheetState = CommunityInteractionGateSheetState(
                kind: .proveAndJoinToPost,
                communityId: pending.communityId,
                communityName: pending.communityName,
                title: "Join \(pending.communityName)",
                message: "Join this community before you post.",
                primaryTitle: "Join",
                secondaryTitle: "Cancel",
                requirements: requirements
            )
            return
        }

        if provider == "token" {
            presentPostBlockedSheet(
                eligibility: eligibility,
                title: "Can't post here",
                message: tokenGateMessage(eligibility: eligibility, action: "post")
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
            title: "Verify to post",
            message: "Complete verification, then return here to create your post.",
            primaryTitle: provider == "very" ? "Verify with Very" : "Verify with ID",
            secondaryTitle: "Cancel",
            requirements: requirements,
            route: route,
            selfRequestedCapabilities: selfRequestedCapabilities(for: eligibility),
            selfVerificationRequirements: verificationRequirements(for: eligibility.membershipGateSummaries)
        )
    }

    private func presentReplyVerificationSheet(eligibility: JoinEligibility) {
        guard let pending = pendingPostReplyAccess else { return }
        let provider = verificationProvider(for: eligibility)
        let requirements = eligibility.membershipGateSummaries ?? []

        if missingCapabilities(eligibility).contains("altcha_pow") || provider == "altcha" {
            sheetState = CommunityInteractionGateSheetState(
                kind: .proveAndJoinToReply,
                communityId: pending.communityId,
                communityName: pending.communityName,
                title: "Join \(pending.communityName)",
                message: "Join this community before you comment.",
                primaryTitle: "Join",
                secondaryTitle: "Cancel",
                requirements: requirements
            )
            return
        }

        if provider == "token" {
            presentReplyBlockedSheet(
                eligibility: eligibility,
                title: "Can't comment here",
                message: tokenGateMessage(eligibility: eligibility, action: "comment")
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
            kind: .verifyToReply(provider: provider ?? "self"),
            communityId: pending.communityId,
            communityName: pending.communityName,
            title: "Verify to comment",
            message: "Complete verification, then return here to comment.",
            primaryTitle: provider == "very" ? "Verify with Very" : "Verify with ID",
            secondaryTitle: "Cancel",
            requirements: requirements,
            route: route,
            selfRequestedCapabilities: selfRequestedCapabilities(for: eligibility),
            selfVerificationRequirements: verificationRequirements(for: eligibility.membershipGateSummaries)
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
                title: "Join \(pending.communityName)",
                message: "Join this community before you vote.",
                primaryTitle: "Join",
                secondaryTitle: "Cancel",
                requirements: requirements
            )
            return
        }

        if provider == "token" {
            presentBlockedSheet(
                eligibility: eligibility,
                title: "Can't vote here",
                message: tokenGateMessage(eligibility: eligibility, action: "vote")
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

    private func presentPostBlockedSheet(eligibility: JoinEligibility, title: String, message: String) {
        guard let pending = pendingPostCompose else { return }
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

    private func presentReplyBlockedSheet(eligibility: JoinEligibility, title: String, message: String) {
        guard let pending = pendingPostReplyAccess else { return }
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

    private func presentCommunityBlockedSheet(eligibility: JoinEligibility, title: String, message: String) {
        guard let pending = pendingCommunityJoin else { return }
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
        if let pending = pendingCommunityJoin {
            let requirements = sheetState?.requirements ?? []
            sheetState = CommunityInteractionGateSheetState(
                kind: .error,
                communityId: pending.communityId,
                communityName: pending.communityName,
                title: joinErrorTitle(for: pending.communityName, message: message),
                message: message,
                primaryTitle: "Try again",
                secondaryTitle: "Cancel",
                requirements: requirements
            )
            return
        }

        if let pending = pendingPostCompose {
            let requirements = sheetState?.requirements ?? []
            sheetState = CommunityInteractionGateSheetState(
                kind: .error,
                communityId: pending.communityId,
                communityName: pending.communityName,
                title: joinErrorTitle(for: pending.communityName, message: message),
                message: message,
                primaryTitle: "Try again",
                secondaryTitle: "Cancel",
                requirements: requirements
            )
            return
        }
        if let pending = pendingPostReplyAccess {
            let requirements = sheetState?.requirements ?? []
            sheetState = CommunityInteractionGateSheetState(
                kind: .error,
                communityId: pending.communityId,
                communityName: pending.communityName,
                title: joinErrorTitle(for: pending.communityName, message: message),
                message: message,
                primaryTitle: "Try again",
                secondaryTitle: "Cancel",
                requirements: requirements
            )
            return
        }
        guard let pending = pendingPostVote else {
            inlineError = message
            return
        }
        sheetState = CommunityInteractionGateSheetState(
            kind: .error,
            communityId: pending.communityId,
            communityName: pending.communityName,
            title: voteErrorTitle(message: message),
            message: message,
            primaryTitle: "Try again",
            secondaryTitle: "Cancel",
            requirements: []
        )
    }

    private func joinErrorTitle(for communityName: String, message: String) -> String {
        message.localizedCaseInsensitiveContains("timed out")
            ? "Proof-of-work timed out"
            : "Couldn't join \(communityName)"
    }

    private func voteErrorTitle(message: String) -> String {
        message.localizedCaseInsensitiveContains("timed out")
            ? "Proof-of-work timed out"
            : "Vote failed"
    }

    private func voteActionTitle(_ value: Int) -> String {
        value == 1 ? "Upvoting" : "Downvoting"
    }

    private func joinThenVote(needsJoinAltcha: Bool) async {
        guard let pending = pendingPostVote else { return }
        do {
            let eligibility = try await eligibility(for: pending.communityId)
            let communityRef = publicCommunityRef(eligibility: eligibility, fallback: pending.communityId)
            let joinPayload: String?
            if needsJoinAltcha {
                sheetState = CommunityInteractionGateSheetState(
                    kind: .proveAndJoinToVote,
                    communityId: pending.communityId,
                    communityName: pending.communityName,
                    title: voteActionTitle(pending.value),
                    message: voteProofOfWorkProgressMessage,
                    primaryTitle: nil,
                    secondaryTitle: "Cancel",
                    requirements: [],
                    isWorking: true
                )
                joinPayload = try await solveAltcha(scope: "community_join", action: "community:\(communityRef)")
            } else {
                joinPayload = nil
            }
            _ = try await ApiClient.shared.joinCommunity(
                communityId: pending.communityId,
                altchaPayload: joinPayload
            )
            eligibilityCache[pending.communityId] = nil
            await voteWithProof()
        } catch let error as ApiError {
            presentError(message: error.displayMessage)
        } catch {
            presentError(message: error.localizedDescription)
        }
    }

    private func joinThenCompose(needsJoinAltcha: Bool) async {
        guard let pending = pendingPostCompose else { return }
        do {
            let eligibility = try await eligibility(for: pending.communityId)
            let communityRef = publicCommunityRef(eligibility: eligibility, fallback: pending.communityId)
            let requirements = eligibility.membershipGateSummaries ?? []
            let joinPayload: String?
            if needsJoinAltcha {
                sheetState = CommunityInteractionGateSheetState(
                    kind: .proveAndJoinToPost,
                    communityId: pending.communityId,
                    communityName: pending.communityName,
                    title: "Joining \(pending.communityName)",
                    message: proofOfWorkProgressMessage,
                    primaryTitle: nil,
                    secondaryTitle: "Cancel",
                    requirements: requirements,
                    isWorking: true
                )
                joinPayload = try await solveAltcha(scope: "community_join", action: "community:\(communityRef)")
            } else {
                joinPayload = nil
            }
            _ = try await ApiClient.shared.joinCommunity(
                communityId: pending.communityId,
                altchaPayload: joinPayload
            )
            eligibilityCache[pending.communityId] = nil
            pendingPostCompose = nil
            sheetState = nil
            pending.continueAfterJoin()
        } catch let error as ApiError {
            presentError(message: error.displayMessage)
        } catch {
            presentError(message: error.localizedDescription)
        }
    }

    private func joinThenReply(needsJoinAltcha: Bool) async {
        guard let pending = pendingPostReplyAccess else { return }
        do {
            let eligibility = try await eligibility(for: pending.communityId)
            let communityRef = publicCommunityRef(eligibility: eligibility, fallback: pending.communityId)
            let requirements = eligibility.membershipGateSummaries ?? []
            let joinPayload: String?
            if needsJoinAltcha {
                sheetState = CommunityInteractionGateSheetState(
                    kind: .proveAndJoinToReply,
                    communityId: pending.communityId,
                    communityName: pending.communityName,
                    title: "Joining \(pending.communityName)",
                    message: proofOfWorkProgressMessage,
                    primaryTitle: nil,
                    secondaryTitle: "Cancel",
                    requirements: requirements,
                    isWorking: true
                )
                joinPayload = try await solveAltcha(scope: "community_join", action: "community:\(communityRef)")
            } else {
                joinPayload = nil
            }
            _ = try await ApiClient.shared.joinCommunity(
                communityId: pending.communityId,
                altchaPayload: joinPayload
            )
            eligibilityCache[pending.communityId] = nil
            pendingPostReplyAccess = nil
            sheetState = nil
            pending.continueAfterAccess()
        } catch let error as ApiError {
            presentError(message: error.displayMessage)
        } catch {
            presentError(message: error.localizedDescription)
        }
    }

    private func joinCommunityFromSheet(needsJoinAltcha: Bool) async {
        guard let pending = pendingCommunityJoin else { return }
        do {
            let eligibility = try await eligibility(for: pending.communityId)
            let communityRef = publicCommunityRef(eligibility: eligibility, fallback: pending.communityId)
            let requirements = eligibility.membershipGateSummaries ?? []
            let joinPayload: String?
            if needsJoinAltcha {
                sheetState = CommunityInteractionGateSheetState(
                    kind: .proveAndJoinCommunity,
                    communityId: pending.communityId,
                    communityName: pending.communityName,
                    title: "Joining \(pending.communityName)",
                    message: proofOfWorkProgressMessage,
                    primaryTitle: nil,
                    secondaryTitle: "Cancel",
                    requirements: requirements,
                    isWorking: true
                )
                joinPayload = try await solveAltcha(scope: "community_join", action: "community:\(communityRef)")
            } else {
                joinPayload = nil
            }
            _ = try await ApiClient.shared.joinCommunity(
                communityId: pending.communityId,
                altchaPayload: joinPayload
            )
            eligibilityCache[pending.communityId] = nil
            pendingCommunityJoin = nil
            sheetState = nil
            pending.didJoin()
        } catch let error as ApiError {
            presentError(message: error.displayMessage)
        } catch {
            presentError(message: error.localizedDescription)
        }
    }

    private func voteWithProof() async {
        guard let pending = pendingPostVote else { return }
        presentVoteProgress(communityId: pending.communityId, communityName: pending.communityName, value: pending.value)
        do {
            let payload = try await solvePostVotePayload(postId: pending.postId, value: pending.value)
            guard pendingPostVote != nil else { return }
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

    private func presentVoteProgress(communityId: String, communityName: String, value: Int) {
        sheetState = CommunityInteractionGateSheetState(
            kind: .proveAndVote,
            communityId: communityId,
            communityName: communityName,
            title: voteActionTitle(value),
            message: voteProofOfWorkProgressMessage,
            primaryTitle: nil,
            secondaryTitle: "Cancel",
            requirements: [],
            isWorking: true
        )
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

    private var proofOfWorkProgressMessage: String {
        "Completing a proof-of-work challenge to confirm you're not spamming."
    }

    private var voteProofOfWorkProgressMessage: String {
        "Solving a quick proof-of-work challenge for this vote."
    }

    private func setWorking(_ isWorking: Bool) {
        guard var state = sheetState else { return }
        state.isWorking = isWorking
        sheetState = state
    }

    private func verificationProvider(for eligibility: JoinEligibility) -> String? {
        if let normalized = eligibility.suggestedVerificationProvider?.lowercased() {
            if normalized.contains("altcha") { return "altcha" }
            if normalized.contains("very") { return "very" }
            if normalized.contains("passport") || normalized.contains("wallet_score") { return "passport" }
            if normalized.contains("nft") || normalized.contains("erc721") || normalized.contains("token") { return "token" }
            if normalized.contains("self") { return "self" }
            if !normalized.isEmpty { return normalized }
        }
        if missingCapabilities(eligibility).contains("altcha_pow") ||
            eligibility.membershipGateSummaries?.contains(where: { $0.gateType == "altcha_pow" }) == true {
            return "altcha"
        }
        if requiresTokenOwnership(eligibility) {
            return "token"
        }
        if requiresSelfVerification(eligibility) {
            return "self"
        }
        return nil
    }

    private func requiresSelfVerification(_ eligibility: JoinEligibility) -> Bool {
        let selfCapabilities: Set<String> = ["age_over_18", "nationality", "gender"]
        if missingCapabilities(eligibility).contains(where: { selfCapabilities.contains($0) }) {
            return true
        }

        let selfGateTypes: Set<String> = ["minimum_age", "nationality", "gender", "self_minimum_age", "self_nationality", "self_excluded_nationality", "self_gender"]
        return eligibility.membershipGateSummaries?.contains(where: { summary in
            if summary.gateType.map({ selfGateTypes.contains($0) }) == true {
                return true
            }
            return summary.acceptedProviders?.contains(where: { $0.lowercased().contains("self") }) == true
        }) == true
    }

    private func requiresTokenOwnership(_ eligibility: JoinEligibility) -> Bool {
        let tokenCapabilities: Set<String> = ["erc721_holding", "erc721_inventory_match", "wallet_nft", "courtyard_inventory"]
        if missingCapabilities(eligibility).contains(where: { tokenCapabilities.contains($0) }) {
            return true
        }
        if let reason = eligibility.failureReason?.lowercased(),
           reason.contains("erc721") || reason.contains("token_inventory") || reason.contains("nft") {
            return true
        }
        let tokenGateTypes: Set<String> = ["erc721_holding", "erc721_inventory_match", "wallet_nft", "courtyard_inventory"]
        let summaries = eligibility.membershipGateSummaries ?? []
        return !summaries.isEmpty
            && summaries.allSatisfy { tokenGateTypes.contains($0.gateType ?? "") }
    }

    private func missingCapabilities(_ eligibility: JoinEligibility) -> [String] {
        eligibility.missingCapabilities ?? []
    }

    private func isProofOfWorkOnly(_ eligibility: JoinEligibility) -> Bool {
        hasProofOfWorkGate(eligibility)
    }

    private func hasProofOfWorkGate(_ eligibility: JoinEligibility) -> Bool {
        missingCapabilities(eligibility).contains("altcha_pow")
            || eligibility.membershipGateSummaries?.contains(where: { $0.gateType == "altcha_pow" }) == true
    }

    private func tokenGateMessage(eligibility: JoinEligibility, action: String) -> String {
        if let reason = eligibility.failureReason, !reason.isEmpty {
            return humanizedGateFailure(reason)
        }
        let hasInventoryGate = eligibility.membershipGateSummaries?.contains { $0.gateType == "erc721_inventory_match" || $0.gateType == "courtyard_inventory" } == true
        if hasInventoryGate {
            return "This community requires matching collectibles before you can \(action)."
        }
        return "This community requires NFT ownership before you can \(action)."
    }

    private func humanizedGateFailure(_ reason: String) -> String {
        switch reason {
        case "erc721_holding_required":
            return "This community requires NFT ownership."
        case "erc721_inventory_match_required":
            return "This community requires matching collectibles."
        case "token_inventory_unavailable":
            return "We could not verify your token inventory yet."
        default:
            return reason.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private var isVerificationSheetActive: Bool {
        switch sheetState?.kind {
        case .verifyToVote, .verifyToReply:
            return true
        default:
            return false
        }
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

                    if state.isWorking && state.primaryTitle == nil {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(colors.accentBrand)
                            Text("Solving proof-of-work...")
                                .font(PirateTokens.Typography.bodyStrong)
                                .foregroundStyle(colors.textPrimary)
                            Spacer()
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
                        }
                    }
                }
            }
            .padding(PirateTokens.pageGutter)
        }
        .presentationDetents(presentationDetents)
        .presentationDragIndicator(.visible)
        .background(colors.bgPage)
    }

    private var presentationDetents: Set<PresentationDetent> {
        guard let state = controller.sheetState else { return [.height(260)] }
        if state.kind == .error {
            return [.height(240)]
        }
        if state.requirements.isEmpty {
            return state.primaryTitle == nil
                ? [.height(250)]
                : [.height(300)]
        }
        let height = min(560, 300 + state.requirements.count * 48)
        return [.height(CGFloat(height)), .large]
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
