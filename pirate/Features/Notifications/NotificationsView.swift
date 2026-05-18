import SwiftUI

struct NotificationsView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    var sessionManager: SessionManager

    @State private var summary: NotificationSummary?
    @State private var tasks: [UserTask] = []
    @State private var feedItems: [NotificationFeedItem] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    MobilePageHeader("Notifications")

                    if let summary = summary, (summary.openTaskCount ?? 0) > 0 {
                        tasksSection
                    }

                    if feedItems.isEmpty && !isLoading {
                        EmptyStateView(
                            icon: "bell",
                            title: "No notifications",
                            subtitle: "Activity from your communities will appear here."
                        )
                    } else {
                        ForEach(feedItems) { item in
                            notificationRow(item)
                            Divider().overlay(colors.borderSoft)
                        }
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
            Text("Tasks")
                .font(PirateTokens.Typography.label)
                .foregroundStyle(colors.textSecondary)
                .padding(.horizontal, PirateTokens.pageGutter)

            ForEach(tasks) { task in
                taskRow(task)
            }
        }
        .padding(.vertical, 8)
    }

    private func taskRow(_ task: UserTask) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 18))
                .foregroundStyle(colors.accentWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.type ?? "Task")
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textPrimary)
                if let subject = task.subject {
                    Text(subject)
                        .font(PirateTokens.Typography.small)
                        .foregroundStyle(colors.textSecondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 8)
    }

    private func notificationRow(_ item: NotificationFeedItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: notificationIcon(for: item.event?.type))
                .font(.system(size: 18))
                .foregroundStyle(colors.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.event?.type ?? "Activity")
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textPrimary)
                if let created = item.event?.created {
                    Text(relativeTime(from: created))
                        .font(PirateTokens.Typography.small)
                        .foregroundStyle(colors.textSecondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 10)
    }

    private func notificationIcon(for type: String?) -> String {
        switch type {
        case "community_join": return "person.badge.plus"
        case "post_upvote": return "arrow.up.circle"
        case "comment_reply": return "bubble.left"
        case "community_post": return "doc.text"
        default: return "bell"
        }
    }

    private func loadNotifications() async {
        isLoading = true
        errorMessage = nil
        do {
            async let summaryTask = ApiClient.shared.notificationSummary()
            async let feedTask = ApiClient.shared.notificationFeed(limit: 25)
            let (summaryResult, feedResult) = try await (summaryTask, feedTask)
            summary = summaryResult
            feedItems = feedResult.items
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func relativeTime(from isoString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: isoString) else { return "" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 2592000 { return "\(Int(interval / 86400))d ago" }
        return "\(Int(interval / 2592000))mo ago"
    }
}
