import Foundation

struct ErrorResponse: Codable {
    let code: String?
    let message: String?
    let retryable: Bool?
    let details: JSONValue?

    enum CodingKeys: String, CodingKey {
        case code, message, retryable, details
    }

    var displayMessage: String {
        switch code {
        case "auth_error": return "Sign in to continue."
        case "internal_error": return "Something went wrong. Please try again."
        default: return message ?? "An unknown error occurred."
    }
    }
}
