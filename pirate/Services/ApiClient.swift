import Foundation

enum ApiError: Error {
    case networkError(NetworkError)
    case serverError(statusCode: Int, message: String, code: String?, retryable: Bool, details: JSONValue? = nil)
    case decodingError(String)
    case unauthorized(String)
    case unknown(String)

    var displayMessage: String {
        switch self {
        case .networkError:
            return "Unable to connect. Please check your internet connection."
        case .serverError(_, let message, let code, _, _):
            if code == "auth_error" { return "Sign in to continue." }
            if code == "internal_error" { return "Something went wrong. Please try again." }
            return message
        case .decodingError:
            return "Something went wrong. Please try again."
        case .unauthorized:
            return "Sign in to continue."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }

    var diagnosticMessage: String {
        switch self {
        case .serverError(let statusCode, let message, let code, _, _):
            let codeLabel = code ?? "unknown"
            if message == displayMessage {
                return "\(message) (HTTP \(statusCode), \(codeLabel))"
            }
            return "\(displayMessage) (HTTP \(statusCode), \(codeLabel): \(message))"
        case .decodingError(let message):
            return "\(displayMessage) (\(message))"
        case .unauthorized(let message):
            return "\(displayMessage) (\(message))"
        case .unknown(let message):
            return "\(displayMessage) (\(message))"
        case .networkError:
            return displayMessage
        }
    }

    var isAuthError: Bool {
        if case .serverError(_, _, let code, _, _) = self, code == "auth_error" { return true }
        if case .unauthorized = self { return true }
        return false
    }

    var isNotFound: Bool {
        if case .serverError(let statusCode, _, _, _, _) = self, statusCode == 404 { return true }
        return false
    }

    var isForbidden: Bool {
        if case .serverError(let statusCode, _, _, _, _) = self, statusCode == 403 { return true }
        return false
    }

    var isRetryable: Bool {
        if case .serverError(_, _, _, let retryable, _) = self { return retryable }
        return false
    }

    var code: String? {
        if case .serverError(_, _, let code, _, _) = self { return code }
        if case .unauthorized = self { return "auth_error" }
        return nil
    }

    var details: JSONValue? {
        if case .serverError(_, _, _, _, let details) = self { return details }
        return nil
    }
}

enum NetworkError: Error {
    case noConnection
    case timeout
    case other(String)
}

enum HTTPMethod: String {
    case GET, POST, PUT, DELETE, PATCH
}

private let altchaHeaderName = "x-pirate-altcha"

final class ApiClient {
    static let shared = ApiClient()

    private var baseURL: URL = URL(string: "https://api.pirate.sc")!
    private let session: URLSession
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    private var accessToken: String?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.jsonDecoder = JSONDecoder()
        self.jsonEncoder = JSONEncoder()
    }

    func setBaseURL(_ url: URL) {
        self.baseURL = url
    }

    func publicMediaURL(from value: String?) -> URL? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        let normalized = trimmed.lowercased()
        if normalized.hasPrefix("http://") || normalized.hasPrefix("https://") || normalized.hasPrefix("data:") {
            return URL(string: trimmed)
        }

        if trimmed.range(of: "^[A-Za-z][A-Za-z0-9+.-]*:", options: .regularExpression) != nil {
            return nil
        }

        if trimmed.hasPrefix("/") {
            return URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
        }
        return baseURL.appendingPathComponent(trimmed)
    }

    func setAccessToken(_ token: String?) {
        self.accessToken = token
    }

    func authorizationHeaders() -> [String: String]? {
        guard let accessToken else { return nil }
        return ["Authorization": "Bearer \(accessToken)"]
    }

    func makeURL(path: String, queryItems: [URLQueryItem]? = nil) -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems?.isEmpty == true ? nil : queryItems
        return components.url!
    }

    static func makeQueryItems(_ values: (name: String, value: String?)...) -> [URLQueryItem]? {
        let items = values.compactMap { item -> URLQueryItem? in
            guard let value = item.value else { return nil }
            return URLQueryItem(name: item.name, value: value)
        }
        return items.isEmpty ? nil : items
    }

    func pathSegment(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#[]@!$&'()*+,;=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private func makeRequest(
        path: String,
        method: HTTPMethod = .GET,
        body: Data? = nil,
        queryItems: [URLQueryItem]? = nil,
        requireAuth: Bool = true,
        contentType: String? = "application/json",
        headers: [String: String]? = nil
    ) -> URLRequest {
        let url = makeURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if requireAuth, let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = body
        }

        return request
    }

    func request<T: Decodable>(path: String, method: HTTPMethod = .GET, body: Data? = nil, queryItems: [URLQueryItem]? = nil, requireAuth: Bool = true, headers: [String: String]? = nil) async throws -> T {
        let request = makeRequest(path: path, method: method, body: body, queryItems: queryItems, requireAuth: requireAuth, headers: headers)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ApiError.networkError(.noConnection)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.serverError(statusCode: 0, message: "Invalid response", code: nil, retryable: false)
        }

        if httpResponse.statusCode == 401 {
            if let errorResponse = try? jsonDecoder.decode(ErrorResponse.self, from: data) {
                throw ApiError.unauthorized(errorResponse.displayMessage)
            }
            throw ApiError.unauthorized("Session expired")
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? jsonDecoder.decode(ErrorResponse.self, from: data) {
                #if DEBUG
                print("[ApiClient] \(method.rawValue) \(path) failed HTTP \(httpResponse.statusCode) code=\(errorResponse.code ?? "nil") message=\(errorResponse.message ?? "nil")")
                #endif
                throw ApiError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse.message ?? errorResponse.displayMessage,
                    code: errorResponse.code,
                    retryable: errorResponse.retryable ?? false,
                    details: errorResponse.details
                )
            }
            throw ApiError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Request failed with status \(httpResponse.statusCode)",
                code: nil,
                retryable: httpResponse.statusCode >= 500
            )
        }

        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            let diagnostic = Self.describeDecodingError(error)
            #if DEBUG
            print("[ApiClient] \(method.rawValue) \(path) decode failed for \(T.self): \(diagnostic)")
            print("[ApiClient] response preview: \(Self.redactedResponsePreview(from: data))")
            #endif
            throw ApiError.decodingError(diagnostic)
        }
    }

    func requestOptionalAuth<T: Decodable>(path: String, method: HTTPMethod = .GET, body: Data? = nil, queryItems: [URLQueryItem]? = nil, headers: [String: String]? = nil) async throws -> T {
        do {
            return try await request(path: path, method: method, body: body, queryItems: queryItems, requireAuth: true, headers: headers)
        } catch let error as ApiError {
            if error.isAuthError {
                return try await request(path: path, method: method, body: body, queryItems: queryItems, requireAuth: false, headers: headers)
            }
            throw error
        }
    }

    func requestVoid(path: String, method: HTTPMethod = .POST, body: Data? = nil, queryItems: [URLQueryItem]? = nil, requireAuth: Bool = true, headers: [String: String]? = nil) async throws {
        let request = makeRequest(path: path, method: method, body: body, queryItems: queryItems, requireAuth: requireAuth, headers: headers)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ApiError.networkError(.noConnection)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.serverError(statusCode: 0, message: "Invalid response", code: nil, retryable: false)
        }

        if httpResponse.statusCode == 401 {
            throw ApiError.unauthorized("Session expired")
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? jsonDecoder.decode(ErrorResponse.self, from: data) {
                #if DEBUG
                print("[ApiClient] \(method.rawValue) \(path) failed HTTP \(httpResponse.statusCode) code=\(errorResponse.code ?? "nil") message=\(errorResponse.message ?? "nil")")
                #endif
                throw ApiError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse.message ?? errorResponse.displayMessage,
                    code: errorResponse.code,
                    retryable: errorResponse.retryable ?? false,
                    details: errorResponse.details
                )
            }
            throw ApiError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Request failed with status \(httpResponse.statusCode)",
                code: nil,
                retryable: httpResponse.statusCode >= 500
            )
        }
    }

    func requestMultipart<T: Decodable>(path: String, body: Data, boundary: String) async throws -> T {
        let request = makeRequest(
            path: path,
            method: .POST,
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )

        let (responseData, response): (Data, URLResponse)
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw ApiError.networkError(.noConnection)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiError.serverError(statusCode: 0, message: "Invalid response", code: nil, retryable: false)
        }

        if httpResponse.statusCode == 401 {
            throw ApiError.unauthorized("Session expired")
        }

        if httpResponse.statusCode >= 400 {
            if let errorResponse = try? jsonDecoder.decode(ErrorResponse.self, from: responseData) {
                throw ApiError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: errorResponse.message ?? errorResponse.displayMessage,
                    code: errorResponse.code,
                    retryable: errorResponse.retryable ?? false,
                    details: errorResponse.details
                )
            }
            throw ApiError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Request failed with status \(httpResponse.statusCode)",
                code: nil,
                retryable: httpResponse.statusCode >= 500
            )
        }

        do {
            return try jsonDecoder.decode(T.self, from: responseData)
        } catch {
            throw ApiError.decodingError(Self.describeDecodingError(error))
        }
    }

    func encode<T: Encodable>(_ value: T) -> Data? {
        try? jsonEncoder.encode(value)
    }

    func altchaHeaders(_ payload: String?) -> [String: String]? {
        guard let payload = payload?.trimmingCharacters(in: .whitespacesAndNewlines), !payload.isEmpty else {
            return nil
        }
        return [altchaHeaderName: payload]
    }

    private static func describeDecodingError(_ error: Error) -> String {
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .typeMismatch(let type, let context):
                return "Type mismatch for \(type) at \(formatCodingPath(context.codingPath)): \(context.debugDescription)"
            case .valueNotFound(let type, let context):
                return "Missing value for \(type) at \(formatCodingPath(context.codingPath)): \(context.debugDescription)"
            case .keyNotFound(let key, let context):
                let path = formatCodingPath(context.codingPath + [key])
                return "Missing key at \(path): \(context.debugDescription)"
            case .dataCorrupted(let context):
                return "Data corrupted at \(formatCodingPath(context.codingPath)): \(context.debugDescription)"
            @unknown default:
                return error.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private static func formatCodingPath(_ codingPath: [CodingKey]) -> String {
        guard !codingPath.isEmpty else { return "<root>" }
        return codingPath.map(\.stringValue).joined(separator: ".")
    }

    private static func redactedResponsePreview(from data: Data) -> String {
        let maxLength = 1_500
        guard !data.isEmpty else { return "<empty>" }

        if var object = try? JSONSerialization.jsonObject(with: data) {
            redactSensitiveFields(in: &object)
            if let redactedData = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
               let redactedString = String(data: redactedData, encoding: .utf8) {
                return String(redactedString.prefix(maxLength))
            }
        }

        let fallback = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>"
        return String(fallback.prefix(maxLength))
    }

    private static func redactSensitiveFields(in value: inout Any) {
        let sensitiveKeys = Set(["access_token", "token", "jwt", "privy_access_token"])

        if var dictionary = value as? [String: Any] {
            for key in dictionary.keys {
                if sensitiveKeys.contains(key) {
                    dictionary[key] = "<redacted>"
                } else if var nested = dictionary[key] {
                    redactSensitiveFields(in: &nested)
                    dictionary[key] = nested
                }
            }
            value = dictionary
        } else if var array = value as? [Any] {
            for index in array.indices {
                var nested = array[index]
                redactSensitiveFields(in: &nested)
                array[index] = nested
            }
            value = array
        }
    }
}
