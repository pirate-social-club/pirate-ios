import Foundation

// MARK: - Onboarding
extension ApiClient {
    func onboardingStatus() async throws -> OnboardingStatus {
        return try await request(path: "/onboarding/status")
    }

    func dismissOnboarding() async throws {
        try await requestVoid(path: "/onboarding/dismiss", method: .POST)
    }
}
