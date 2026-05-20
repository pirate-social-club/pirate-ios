import SwiftUI

struct NotificationsView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    var sessionManager: SessionManager

    @State private var tasks: [UserTask] = []
    @State private var feedItems: [NotificationFeedItem] = []
    @State private var nextCursor: String?
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var verifyingHumanTaskId: String?
    @State private var errorMessage: String?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    MobilePageHeader("Notifications")

                    if let errorMessage {
                        notificationNotice(
                            icon: "exclamationmark.triangle",
                            title: "Notification action failed",
                            subtitle: errorMessage
                        )
                        .padding(.horizontal, PirateTokens.pageGutter)
                        .padding(.bottom, 12)
                    }

                    if !tasks.isEmpty {
                        tasksSection
                    }

                    if tasks.isEmpty && feedItems.isEmpty && !isLoading {
                        EmptyStateView(
                            icon: "bell",
                            title: "No notifications",
                            subtitle: "Tasks and recent activity will appear here."
                        )
                    } else {
                        ForEach(feedItems) { item in
                            activityRow(item)
                            Divider().overlay(colors.borderSoft)
                        }
                    }

                    if nextCursor != nil {
                        Button {
                            Task { await loadMoreNotifications() }
                        } label: {
                            HStack {
                                if isLoadingMore {
                                    ProgressView()
                                        .tint(colors.textOnAccent)
                                }
                                Text(isLoadingMore ? "Loading..." : "Load more")
                            }
                            .font(PirateTokens.Typography.bodyStrong)
                            .foregroundStyle(colors.textOnAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoadingMore)
                        .padding(PirateTokens.pageGutter)
                    }
                }
            }
            .background(colors.bgPage)
            .hiddenRootNavigationBar()
            .task {
                await loadNotifications()
            }
            .refreshable {
                await loadNotifications()
            }
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(tasks) { task in
                taskRow(task)
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func taskRow(_ task: UserTask) -> some View {
        if task.type == "unique_human_verification_required" {
            Button {
                Task { await startVeryHumanVerification(task) }
            } label: {
                taskRowContent(
                    task,
                    interactive: verifyingHumanTaskId == nil,
                    loading: verifyingHumanTaskId == task.id
                )
            }
            .buttonStyle(.plain)
            .disabled(verifyingHumanTaskId != nil)
        } else if let route = taskRoute(for: task) {
            NavigationLink(value: route) {
                taskRowContent(task, interactive: true)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                if canAutoClearTaskOnOpen(task) {
                    Task { await dismissTask(task) }
                }
            })
        } else {
            taskRowContent(task, interactive: false)
        }
    }

    private func taskRowContent(_ task: UserTask, interactive: Bool, loading: Bool = false) -> some View {
        notificationRow(
            icon: taskIcon(for: task),
            title: taskTitle(for: task),
            subtitle: taskMeta(for: task),
            unread: true,
            interactive: interactive,
            loading: loading
        )
    }

    @ViewBuilder
    private func activityRow(_ item: NotificationFeedItem) -> some View {
        if let route = activityRoute(for: item) {
            if case .verificationVery(let intent) = route {
                Button {
                    Task { await startVeryHumanVerification(task: nil, intent: intent, sourceId: item.id) }
                } label: {
                    activityRowContent(item, interactive: verifyingHumanTaskId == nil, loading: verifyingHumanTaskId == item.id)
                }
                .buttonStyle(.plain)
                .disabled(verifyingHumanTaskId != nil)
            } else {
                NavigationLink(value: route) {
                    activityRowContent(item, interactive: true)
                }
                .buttonStyle(.plain)
            }
        } else {
            activityRowContent(item, interactive: false)
        }
    }

    private func activityRowContent(_ item: NotificationFeedItem, interactive: Bool, loading: Bool = false) -> some View {
        notificationRow(
            icon: activityIcon(for: item),
            title: activityTitle(for: item),
            subtitle: activityContext(for: item),
            meta: formatRelativeTimestamp(item.event?.created),
            unread: item.receipt?.readAt == nil,
            interactive: interactive,
            loading: loading
        )
    }

    private func notificationRow(
        icon: PirateIcon,
        title: String,
        subtitle: String?,
        meta: String? = nil,
        unread: Bool,
        interactive: Bool,
        loading: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(unread ? colors.surfaceAccent : colors.bgPage)
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(colors.borderSoft, lineWidth: 1))
                .overlay(
                    Group {
                        if loading {
                            ProgressView()
                                .tint(colors.accentBrand)
                                .scaleEffect(0.8)
                        } else {
                            PirateIconView(
                                icon: icon,
                                filled: unread,
                                size: 22,
                                color: unread ? colors.textPrimary : colors.textSecondary
                            )
                        }
                    }
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)
                if let detail = [subtitle, meta].compactMap({ $0?.nilIfEmpty }).joined(separator: " · ").nilIfEmpty {
                    Text(detail)
                        .font(PirateTokens.Typography.small)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if interactive && !loading {
                PirateIconView(icon: .caretRight, size: 18, color: colors.textSecondary)
            }
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func notificationNotice(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            PirateSystemIconView(systemName: icon, size: 18)
                .font(.system(size: 18))
                .foregroundStyle(colors.accentWarning)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textPrimary)
                Text(subtitle)
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
        .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))
    }

    private func loadNotifications() async {
        isLoading = true
        errorMessage = nil
        do {
            async let tasksTask = ApiClient.shared.notificationTasks()
            async let feedTask = ApiClient.shared.notificationFeed(limit: 25)
            let (tasksResult, feedResult) = try await (tasksTask, feedTask)
            tasks = tasksResult.items
            let renderableFeed = feedResult.items.filter { $0.event?.type != "xmtp_message" }
            feedItems = renderableFeed
            nextCursor = feedResult.nextCursor
            await markVisibleActivityRead(renderableFeed)
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMoreNotifications() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        errorMessage = nil
        do {
            let feedResult = try await ApiClient.shared.notificationFeed(cursor: cursor, limit: 25)
            let renderableFeed = feedResult.items.filter { $0.event?.type != "xmtp_message" }
            let knownIds = Set(feedItems.map(\.id))
            feedItems += renderableFeed.filter { !knownIds.contains($0.id) }
            nextCursor = feedResult.nextCursor
            await markVisibleActivityRead(renderableFeed)
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMore = false
    }

    private func markVisibleActivityRead(_ items: [NotificationFeedItem]) async {
        let unreadEventIds = items.compactMap { item -> String? in
            guard item.receipt?.readAt == nil else { return nil }
            return item.event?.id
        }
        guard !unreadEventIds.isEmpty else { return }
        try? await ApiClient.shared.markNotificationsRead(eventIds: unreadEventIds)
    }

    private func startVeryHumanVerification(_ task: UserTask) async {
        await startVeryHumanVerification(task: task, intent: "profile_verification", sourceId: task.id)
    }

    private func startVeryHumanVerification(task: UserTask?, intent: String, sourceId: String) async {
        guard verifyingHumanTaskId == nil else { return }
        verifyingHumanTaskId = sourceId
        errorMessage = nil
        defer { verifyingHumanTaskId = nil }

        let result = await VeryVerificationLauncher.launch(verificationIntent: intent)
        guard result.verified else {
            errorMessage = result.failureReason ?? "Very verification was not completed."
            return
        }

        if let task {
            try? await ApiClient.shared.dismissTask(taskId: task.id)
            tasks.removeAll { $0.id == task.id }
        }
        await sessionManager.refreshUser()
        await sessionManager.refreshProfile()
        await loadNotifications()
    }

    private func dismissTask(_ task: UserTask) async {
        do {
            try await ApiClient.shared.dismissTask(taskId: task.id)
            tasks.removeAll { $0.id == task.id }
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func canAutoClearTaskOnOpen(_ task: UserTask) -> Bool {
        !task.id.hasPrefix("synth:") && task.type != "unique_human_verification_required"
    }

    private func taskRoute(for task: UserTask) -> PirateRoute? {
        if let targetPath = task.payloadString("target_path"), let route = route(from: targetPath) {
            return route
        }

        switch task.type {
        case "unique_human_verification_required":
            return .verificationVery("profile_verification")
        case "profile_completion_suggested":
            return .settingsSection("profile")
        case "global_handle_cleanup_suggested":
            return .settingsSection("domains")
        case "namespace_verification_required":
            guard let subject = task.subject?.nilIfEmpty else { return nil }
            return .communityModerationSection(subject, "namespace")
        case "membership_review":
            guard let subject = task.subject?.nilIfEmpty else { return nil }
            return .communityModerationSection(subject, "requests")
        default:
            return nil
        }
    }

    private func activityRoute(for item: NotificationFeedItem) -> PirateRoute? {
        if let targetPath = item.event?.payloadString("target_path"), let route = route(from: targetPath) {
            return route
        }
        if item.event?.type == "comment_reply", let postId = item.event?.payloadString("thread_root_post_id") {
            return .post(postId)
        }
        if item.event?.type == "post_commented", item.event?.subjectType == "post", let postId = item.event?.subject {
            return .post(postId)
        }
        return nil
    }

    private func route(from path: String) -> PirateRoute? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }
        let components = trimmed.split(separator: "?", maxSplits: 1).first?
            .split(separator: "/")
            .map(String.init) ?? []

        if components.first == "onboarding" {
            return .verificationVery("profile_verification")
        }
        if components.first == "settings", components.count > 1 {
            return .settingsSection(components[1])
        }
        if components.first == "p", components.count > 1 {
            return .post(components[1])
        }
        if components.first == "c", components.count >= 4, components[2] == "mod" {
            return .communityModerationSection(components[1], components[3])
        }
        if components.first == "c", components.count > 1 {
            return .community(components[1])
        }
        return nil
    }

    private func taskTitle(for task: UserTask) -> String {
        switch task.type {
        case "unique_human_verification_required":
            return "Verify you're human"
        case "profile_completion_suggested":
            return "Finish your profile"
        case "global_handle_cleanup_suggested":
            return "Pick your free .pirate name"
        case "namespace_verification_required":
            return "Verify your community namespace"
        case "membership_review":
            return "Membership requests"
        default:
            return task.type?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Task"
        }
    }

    private func taskMeta(for task: UserTask) -> String? {
        let communityName = task.payloadString("community_display_name")
        let requestCount = task.payloadInt("request_count")
        switch task.type {
        case "unique_human_verification_required":
            return "Take a photo of your palm"
        case "profile_completion_suggested":
            return "Add a name, bio, avatar, or cover"
        case "global_handle_cleanup_suggested":
            return "Replace your generated signup name"
        case "membership_review":
            return [
                communityName,
                requestCount.map { "\($0) pending" }
            ].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
        default:
            return communityName
        }
    }

    private func taskIcon(for task: UserTask) -> PirateIcon {
        switch task.type {
        case "unique_human_verification_required":
            return .handPalm
        case "namespace_verification_required", "global_handle_cleanup_suggested":
            return .identificationCard
        case "membership_review":
            return .users
        case "profile_completion_suggested":
            return .userCircle
        default:
            return .bell
        }
    }

    private func activityIcon(for item: NotificationFeedItem) -> PirateIcon {
        switch item.event?.type {
        case "royalty_earned":
            return .wallet
        default:
            return .bell
        }
    }

    private func activityTitle(for item: NotificationFeedItem) -> String {
        let actor = item.event?.payloadString("actor_display_name") ?? "Someone"
        switch item.event?.type {
        case "comment_reply":
            return "\(actor) replied to your comment"
        case "post_commented":
            return "\(actor) commented on your post"
        case "royalty_earned":
            return "Royalty earned"
        default:
            return "\(actor) \((item.event?.type ?? "activity").replacingOccurrences(of: "_", with: " "))"
        }
    }

    private func activityContext(for item: NotificationFeedItem) -> String? {
        if item.event?.type == "royalty_earned" {
            let amount = item.event?.payloadString("amount_wip_wei").map(formatWipAmount)
            let title = item.event?.payloadString("title")
            switch (amount, title) {
            case (.some(let amount), .some(let title)):
                return "+\(amount) $WIP from \(title)"
            case (.some(let amount), .none):
                return "+\(amount) $WIP"
            case (.none, .some(let title)):
                return title
            default:
                return nil
            }
        }

        return item.event?.payloadString("comment_excerpt")
            ?? item.event?.payloadString("post_title")
            ?? item.event?.payloadString("context_label")
    }

    private func formatWipAmount(_ wei: String) -> String {
        let digits = String(wei.filter { $0.isNumber })
        guard !digits.isEmpty else { return "0" }
        let padded = String(repeating: "0", count: max(0, 19 - digits.count)) + digits
        let splitIndex = padded.index(padded.endIndex, offsetBy: -18)
        let rawWhole = String(padded[..<splitIndex]).drop { $0 == "0" }
        let whole = rawWhole.isEmpty ? "0" : String(rawWhole)
        let fraction = String(padded[splitIndex...])
        var visibleFraction = String(fraction.prefix(4))
        while visibleFraction.last == "0" {
            visibleFraction.removeLast()
        }
        if whole == "0", fraction.contains(where: { $0 != "0" }), visibleFraction.isEmpty {
            return "<0.0001"
        }
        return visibleFraction.isEmpty ? whole : "\(whole).\(visibleFraction)"
    }
}

private extension UserTask {
    func payloadString(_ key: String) -> String? {
        payload?[key]?.stringValue?.nilIfEmpty
    }

    func payloadInt(_ key: String) -> Int? {
        guard let value = payload?[key] else { return nil }
        switch value {
        case .int(let int):
            return int
        case .double(let double):
            return Int(double)
        case .string(let string):
            return Int(string)
        case .bool, .object, .array, .null:
            return nil
        }
    }
}

private extension NotificationEvent {
    func payloadString(_ key: String) -> String? {
        payload?[key]?.stringValue?.nilIfEmpty
    }
}
