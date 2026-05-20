import XCTest
@testable import pirate

final class JSONValueTests: XCTestCase {
    func testFirstStringValueFindsNestedValuesAcrossObjectsAndArrays() throws {
        let data = """
        {
          "provider": {
            "launches": [
              { "name": "ignored" },
              { "meta": { "mode": "mobile-app" } }
            ]
          },
          "href": "https://example.com/verify"
        }
        """.data(using: .utf8)!

        let value = try JSONDecoder().decode(JSONValue.self, from: data)

        XCTAssertEqual(value.firstStringValue(named: "mode"), "mobile-app")
        XCTAssertEqual(value.firstStringValue(named: "href"), "https://example.com/verify")
        XCTAssertNil(value.firstStringValue(named: "missing"))
    }

    func testStringValueCoercesScalarsOnly() {
        XCTAssertEqual(JSONValue.string("ready").stringValue, "ready")
        XCTAssertEqual(JSONValue.int(42).stringValue, "42")
        XCTAssertEqual(JSONValue.double(4.5).stringValue, "4.5")
        XCTAssertEqual(JSONValue.bool(true).stringValue, "true")
        XCTAssertNil(JSONValue.object([:]).stringValue)
        XCTAssertNil(JSONValue.array([]).stringValue)
        XCTAssertNil(JSONValue.null.stringValue)
    }

    func testIntValueCoercesNumericScalarsOnly() {
        XCTAssertEqual(JSONValue.int(42).intValue, 42)
        XCTAssertEqual(JSONValue.double(4.5).intValue, 4)
        XCTAssertEqual(JSONValue.string("17").intValue, 17)
        XCTAssertNil(JSONValue.string("seventeen").intValue)
        XCTAssertNil(JSONValue.bool(true).intValue)
        XCTAssertNil(JSONValue.object([:]).intValue)
    }

    func testBoolValueCoercesBooleanScalarsOnly() {
        XCTAssertEqual(JSONValue.bool(true).boolValue, true)
        XCTAssertEqual(JSONValue.bool(false).boolValue, false)
        XCTAssertEqual(JSONValue.string("true").boolValue, true)
        XCTAssertEqual(JSONValue.string("false").boolValue, false)
        XCTAssertNil(JSONValue.string("yes").boolValue)
        XCTAssertNil(JSONValue.int(1).boolValue)
        XCTAssertNil(JSONValue.array([]).boolValue)
    }

    func testKeyedContainerLossyDecodingCoercesSupportedScalarTypes() throws {
        let data = """
        {
          "string_from_int": 42,
          "string_from_bool": true,
          "int_from_string": "17",
          "int_from_double": 9.8,
          "double_from_string": "12.5",
          "double_from_int": 6,
          "bool_from_true_string": "true",
          "bool_from_false_string": "false",
          "invalid_bool": "yes",
          "invalid_int": "seventeen"
        }
        """.data(using: .utf8)!

        let value = try JSONDecoder().decode(LossyDecodedScalars.self, from: data)

        XCTAssertEqual(value.stringFromInt, "42")
        XCTAssertEqual(value.stringFromBool, "true")
        XCTAssertEqual(value.intFromString, 17)
        XCTAssertEqual(value.intFromDouble, 9)
        XCTAssertEqual(value.doubleFromString, 12.5)
        XCTAssertEqual(value.doubleFromInt, 6)
        XCTAssertEqual(value.boolFromTrueString, true)
        XCTAssertEqual(value.boolFromFalseString, false)
        XCTAssertNil(value.invalidBool)
        XCTAssertNil(value.invalidInt)
    }
}

private struct LossyDecodedScalars: Decodable {
    let stringFromInt: String?
    let stringFromBool: String?
    let intFromString: Int?
    let intFromDouble: Int?
    let doubleFromString: Double?
    let doubleFromInt: Double?
    let boolFromTrueString: Bool?
    let boolFromFalseString: Bool?
    let invalidBool: Bool?
    let invalidInt: Int?

    enum CodingKeys: String, CodingKey {
        case stringFromInt = "string_from_int"
        case stringFromBool = "string_from_bool"
        case intFromString = "int_from_string"
        case intFromDouble = "int_from_double"
        case doubleFromString = "double_from_string"
        case doubleFromInt = "double_from_int"
        case boolFromTrueString = "bool_from_true_string"
        case boolFromFalseString = "bool_from_false_string"
        case invalidBool = "invalid_bool"
        case invalidInt = "invalid_int"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.stringFromInt = container.decodeLossyStringIfPresent(forKey: .stringFromInt)
        self.stringFromBool = container.decodeLossyStringIfPresent(forKey: .stringFromBool)
        self.intFromString = container.decodeLossyIntIfPresent(forKey: .intFromString)
        self.intFromDouble = container.decodeLossyIntIfPresent(forKey: .intFromDouble)
        self.doubleFromString = container.decodeLossyDoubleIfPresent(forKey: .doubleFromString)
        self.doubleFromInt = container.decodeLossyDoubleIfPresent(forKey: .doubleFromInt)
        self.boolFromTrueString = container.decodeLossyBoolIfPresent(forKey: .boolFromTrueString)
        self.boolFromFalseString = container.decodeLossyBoolIfPresent(forKey: .boolFromFalseString)
        self.invalidBool = container.decodeLossyBoolIfPresent(forKey: .invalidBool)
        self.invalidInt = container.decodeLossyIntIfPresent(forKey: .invalidInt)
    }
}
