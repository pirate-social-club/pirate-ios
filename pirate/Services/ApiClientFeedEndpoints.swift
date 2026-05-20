import Foundation

// MARK: - Feed
extension ApiClient {
    func homeFeed(cursor: String? = nil, locale: String? = nil, sort: String? = nil, timeRange: String? = nil) async throws -> HomeFeedResponse {
        return try await requestOptionalAuth(path: "/feed/home", queryItems: feedQueryItems(cursor: cursor, locale: locale, sort: sort, timeRange: timeRange))
    }

    func publicHomeFeed(cursor: String? = nil, locale: String? = nil, sort: String? = nil, timeRange: String? = nil) async throws -> HomeFeedResponse {
        return try await request(path: "/feed/home/public", queryItems: feedQueryItems(cursor: cursor, locale: locale, sort: sort, timeRange: timeRange), requireAuth: false)
    }

    private func feedQueryItems(cursor: String?, locale: String?, sort: String?, timeRange: String?) -> [URLQueryItem]? {
        Self.makeQueryItems(
            (name: "cursor", value: cursor),
            (name: "locale", value: locale),
            (name: "sort", value: sort),
            (name: "time_range", value: timeRange)
        )
    }
}
