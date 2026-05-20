import XCTest
@testable import pirate

final class SelfVerificationLaunchBuilderTests: XCTestCase {
    func testBuildLaunchURLNormalizesSelfAppPayload() throws {
        let launch = try decodeJSONValue("""
        {
          "self_app": {
            "app_name": "Pirate",
            "endpoint": "https://verify.example.com",
            "endpoint_type": "staging_https",
            "session_id": "session-123",
            "scope": "passport",
            "user": "user-456",
            "user_id_type": "uuid",
            "version": "3",
            "dev_mode": "true",
            "header": "Verify with Pirate",
            "logo_base64": "base64-logo",
            "user_defined_data": "metadata",
            "disclosures": {
              "nationality": true,
              "minimum_age": "21",
              "excluded_countries": ["USA", 44, true]
            }
          }
        }
        """)

        let callbackURL = URL(string: "pirate://verification-callback")!
        let result = SelfVerificationLaunchBuilder.buildLaunchURL(from: launch, callbackURL: callbackURL)

        let payload = try XCTUnwrap(selfAppPayload(from: result.url))
        XCTAssertNil(result.error)
        XCTAssertEqual(payload["appName"] as? String, "Pirate")
        XCTAssertEqual(payload["chainID"] as? Int, 11_142_220)
        XCTAssertEqual(payload["deeplinkCallback"] as? String, callbackURL.absoluteString)
        XCTAssertEqual(payload["devMode"] as? Bool, true)
        XCTAssertEqual(payload["endpoint"] as? String, "https://verify.example.com")
        XCTAssertEqual(payload["endpointType"] as? String, "staging_https")
        XCTAssertEqual(payload["header"] as? String, "Verify with Pirate")
        XCTAssertEqual(payload["logoBase64"] as? String, "base64-logo")
        XCTAssertEqual(payload["scope"] as? String, "passport")
        XCTAssertEqual(payload["sessionId"] as? String, "session-123")
        XCTAssertEqual(payload["userDefinedData"] as? String, "metadata")
        XCTAssertEqual(payload["userId"] as? String, "user-456")
        XCTAssertEqual(payload["userIdType"] as? String, "uuid")
        XCTAssertEqual(payload["version"] as? Int, 3)

        let disclosures = try XCTUnwrap(payload["disclosures"] as? [String: Any])
        XCTAssertEqual(disclosures["nationality"] as? Bool, true)
        XCTAssertEqual(disclosures["minimumAge"] as? Int, 21)
        XCTAssertEqual(disclosures["excludedCountries"] as? [String], ["USA", "44", "true"])
    }

    func testBuildLaunchURLUsesProductionChainDefaultAndLaunchCallback() throws {
        let launch = try decodeJSONValue("""
        {
          "selfApp": {
            "appName": "Pirate",
            "endpoint": "https://verify.example.com",
            "endpointType": "https",
            "sessionId": "session-123",
            "scope": "passport",
            "userId": "user-456",
            "userIdType": "uuid",
            "deeplinkCallback": "pirate://from-launch"
          }
        }
        """)

        let result = SelfVerificationLaunchBuilder.buildLaunchURL(from: launch, callbackURL: nil)

        let payload = try XCTUnwrap(selfAppPayload(from: result.url))
        XCTAssertNil(result.error)
        XCTAssertEqual(payload["chainID"] as? Int, 42_220)
        XCTAssertEqual(payload["deeplinkCallback"] as? String, "pirate://from-launch")
        XCTAssertEqual(payload["version"] as? Int, 2)
        XCTAssertEqual(payload["devMode"] as? Bool, false)
    }

    func testBuildLaunchURLReturnsUsefulErrorForMissingRequiredField() throws {
        let launch = try decodeJSONValue("""
        {
          "self_app": {
            "app_name": "Pirate"
          }
        }
        """)

        let result = SelfVerificationLaunchBuilder.buildLaunchURL(from: launch, callbackURL: nil)

        XCTAssertNil(result.url)
        XCTAssertEqual(result.error, "Self launch data is missing endpoint.")
    }

    private func decodeJSONValue(_ json: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
    }

    private func selfAppPayload(from url: URL?) throws -> [String: Any]? {
        let url = try XCTUnwrap(url)
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "redirect.self.xyz")

        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let selfApp = try XCTUnwrap(components.queryItems?.first { $0.name == "selfApp" }?.value)
        let data = Data(selfApp.utf8)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
