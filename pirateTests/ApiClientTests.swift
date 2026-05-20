import XCTest
@testable import pirate

final class ApiClientTests: XCTestCase {
    func testMakeQueryItemsDropsNilValuesAndPreservesOrder() throws {
        let items = try XCTUnwrap(ApiClient.makeQueryItems(
            (name: "cursor", value: "next page"),
            (name: "sort", value: nil),
            (name: "limit", value: "25"),
            (name: "locale", value: "en-US")
        ))

        XCTAssertEqual(items.map(\.name), ["cursor", "limit", "locale"])
        XCTAssertEqual(items.map(\.value), ["next page", "25", "en-US"])
    }

    func testMakeQueryItemsReturnsNilWhenAllValuesAreNil() {
        XCTAssertNil(ApiClient.makeQueryItems(
            (name: "cursor", value: nil),
            (name: "sort", value: nil)
        ))
    }

    func testPublicMediaURLNormalizesRelativePathsAgainstBaseURL() {
        let client = ApiClient()
        client.setBaseURL(URL(string: "https://api.example.com/v1")!)

        XCTAssertEqual(
            client.publicMediaURL(from: "avatars/user.png")?.absoluteString,
            "https://api.example.com/v1/avatars/user.png"
        )
        XCTAssertEqual(
            client.publicMediaURL(from: "/media/banner.png")?.absoluteString,
            "https://api.example.com/media/banner.png"
        )
    }

    func testPublicMediaURLAllowsWebAndDataURLsButRejectsOtherSchemes() {
        let client = ApiClient()

        XCTAssertEqual(
            client.publicMediaURL(from: "https://cdn.example.com/image.png")?.absoluteString,
            "https://cdn.example.com/image.png"
        )
        XCTAssertEqual(
            client.publicMediaURL(from: "data:image/png;base64,abc123")?.absoluteString,
            "data:image/png;base64,abc123"
        )
        XCTAssertNil(client.publicMediaURL(from: "javascript:alert(1)"))
        XCTAssertNil(client.publicMediaURL(from: "mailto:test@example.com"))
        XCTAssertNil(client.publicMediaURL(from: "   "))
    }
}
