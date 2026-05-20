import Foundation

// MARK: - Notifications
extension ApiClient {
    func notificationSummary() async throws -> NotificationSummary {
        return try await request(path: "/notifications/summary")
    }

    func notificationTasks(cursor: String? = nil) async throws -> NotificationTasksResponse {
        return try await request(path: "/notifications/tasks", queryItems: Self.makeQueryItems((name: "cursor", value: cursor)))
    }

    func notificationFeed(cursor: String? = nil, limit: Int? = nil) async throws -> NotificationFeedResponse {
        return try await request(
            path: "/notifications/feed",
            queryItems: Self.makeQueryItems(
                (name: "cursor", value: cursor),
                (name: "limit", value: limit.map(String.init))
            )
        )
    }

    func markNotificationsRead(eventIds: [String]? = nil) async throws {
        let body: Data?
        if let eventIds {
            body = encode(["event_ids": eventIds])
        } else {
            body = nil
        }
        try await requestVoid(path: "/notifications/mark-read", method: .POST, body: body)
    }

    func dismissTask(taskId: String) async throws {
        try await requestVoid(path: "/notifications/dismiss-task", method: .POST, body: encode(["task_id": taskId]))
    }
}
