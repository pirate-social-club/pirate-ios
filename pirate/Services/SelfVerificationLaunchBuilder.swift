import Foundation

struct SelfVerificationLaunchBuildResult {
    let url: URL?
    let error: String?

    static func success(_ url: URL) -> SelfVerificationLaunchBuildResult {
        SelfVerificationLaunchBuildResult(url: url, error: nil)
    }

    static func failure(_ error: String) -> SelfVerificationLaunchBuildResult {
        SelfVerificationLaunchBuildResult(url: nil, error: error)
    }
}

enum SelfVerificationLaunchBuilder {
    static func buildLaunchURL(from launch: JSONValue?, callbackURL: URL?) -> SelfVerificationLaunchBuildResult {
        guard let launchObject = selfAppObject(from: launch) else {
            return .failure("Self launch data was not returned by the API.")
        }

        guard let appName = stringValue(["app_name", "appName"], in: launchObject)?.nilIfEmpty else {
            return .failure("Self launch data is missing app_name.")
        }
        guard let endpoint = stringValue(["endpoint"], in: launchObject)?.nilIfEmpty else {
            return .failure("Self launch data is missing endpoint.")
        }
        guard let endpointType = stringValue(["endpoint_type", "endpointType"], in: launchObject)?.nilIfEmpty else {
            return .failure("Self launch data is missing endpoint_type.")
        }
        guard let sessionId = stringValue(["session_id", "sessionId"], in: launchObject)?.nilIfEmpty else {
            return .failure("Self launch data is missing session_id.")
        }
        guard let scope = stringValue(["scope"], in: launchObject)?.nilIfEmpty else {
            return .failure("Self launch data is missing scope.")
        }
        guard let userId = stringValue(["user_id", "userId", "user"], in: launchObject)?.nilIfEmpty else {
            return .failure("Self launch data is missing user_id.")
        }
        guard let userIdType = stringValue(["user_id_type", "userIdType"], in: launchObject)?.nilIfEmpty else {
            return .failure("Self launch data is missing user_id_type.")
        }

        let chainId = intValue(["chain_id", "chainID"], in: launchObject) ?? defaultChainId(endpointType: endpointType)
        let version = intValue(["version"], in: launchObject) ?? 2
        let deeplinkCallback = callbackURL?.absoluteString
            ?? stringValue(["deeplink_callback", "deeplinkCallback"], in: launchObject)
            ?? ""

        let payload: [String: Any] = [
            "appName": appName,
            "chainID": chainId,
            "deeplinkCallback": deeplinkCallback,
            "devMode": boolValue(["dev_mode", "devMode"], in: launchObject) ?? false,
            "endpoint": endpoint,
            "endpointType": endpointType,
            "header": stringValue(["header"], in: launchObject) ?? "",
            "logoBase64": stringValue(["logo_base64", "logoBase64"], in: launchObject) ?? "",
            "disclosures": disclosuresPayload(from: launchObject),
            "scope": scope,
            "sessionId": sessionId,
            "userDefinedData": stringValue(["user_defined_data", "userDefinedData"], in: launchObject) ?? "",
            "userId": userId,
            "userIdType": userIdType,
            "version": version
        ]

        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload),
              let selfApp = String(data: data, encoding: .utf8) else {
            return .failure("Could not build Self launch payload.")
        }

        var components = URLComponents(string: "https://redirect.self.xyz")
        components?.queryItems = [URLQueryItem(name: "selfApp", value: selfApp)]
        guard let url = components?.url else {
            return .failure("Could not build Self launch link.")
        }
        return .success(url)
    }

    private static func selfAppObject(from launch: JSONValue?) -> [String: JSONValue]? {
        guard case .object(let object) = launch else { return nil }
        if case .object(let selfApp)? = object["self_app"] {
            return selfApp
        }
        if case .object(let selfApp)? = object["selfApp"] {
            return selfApp
        }
        return nil
    }

    private static func disclosuresPayload(from launchObject: [String: JSONValue]) -> [String: Any] {
        guard let disclosures = objectValue(["disclosures"], in: launchObject) else { return [:] }
        var payload: [String: Any] = [:]

        if boolValue(["issuing_state", "issuingState"], in: disclosures) == true { payload["issuing_state"] = true }
        if boolValue(["name"], in: disclosures) == true { payload["name"] = true }
        if boolValue(["passport_number", "passportNumber"], in: disclosures) == true { payload["passport_number"] = true }
        if boolValue(["nationality"], in: disclosures) == true { payload["nationality"] = true }
        if boolValue(["date_of_birth", "dateOfBirth"], in: disclosures) == true { payload["date_of_birth"] = true }
        if boolValue(["gender"], in: disclosures) == true { payload["gender"] = true }
        if boolValue(["expiry_date", "expiryDate"], in: disclosures) == true { payload["expiry_date"] = true }
        if boolValue(["ofac"], in: disclosures) == true { payload["ofac"] = true }
        if let countries = stringArrayValue(["excluded_countries", "excludedCountries"], in: disclosures), !countries.isEmpty {
            payload["excludedCountries"] = countries
        }
        if let minimumAge = intValue(["minimum_age", "minimumAge"], in: disclosures) {
            payload["minimumAge"] = minimumAge
        }

        return payload
    }

    private static func defaultChainId(endpointType: String) -> Int {
        endpointType == "staging_celo" || endpointType == "staging_https" ? 11_142_220 : 42_220
    }

    private static func objectValue(_ keys: [String], in object: [String: JSONValue]) -> [String: JSONValue]? {
        for key in keys {
            if case .object(let value)? = object[key] {
                return value
            }
        }
        return nil
    }

    private static func stringValue(_ keys: [String], in object: [String: JSONValue]) -> String? {
        for key in keys {
            if let value = object[key]?.stringValue {
                return value
            }
        }
        return nil
    }

    private static func intValue(_ keys: [String], in object: [String: JSONValue]) -> Int? {
        for key in keys {
            guard let value = object[key] else { continue }
            switch value {
            case .int(let int): return int
            case .double(let double): return Int(double)
            case .string(let string): if let int = Int(string) { return int }
            default: break
            }
        }
        return nil
    }

    private static func boolValue(_ keys: [String], in object: [String: JSONValue]) -> Bool? {
        for key in keys {
            guard let value = object[key] else { continue }
            switch value {
            case .bool(let bool): return bool
            case .string(let string):
                if string == "true" { return true }
                if string == "false" { return false }
            default: break
            }
        }
        return nil
    }

    private static func stringArrayValue(_ keys: [String], in object: [String: JSONValue]) -> [String]? {
        for key in keys {
            guard case .array(let values)? = object[key] else { continue }
            return values.compactMap(\.stringValue)
        }
        return nil
    }
}
