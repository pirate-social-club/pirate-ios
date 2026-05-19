import CryptoKit
import Foundation

enum AltchaSolverError: Error, LocalizedError {
    case invalidChallenge(String)
    case timeout
    case unsupportedAlgorithm(String)

    var errorDescription: String? {
        switch self {
        case .invalidChallenge(let message):
            return message
        case .timeout:
            return "Proof-of-work timed out. Please try again."
        case .unsupportedAlgorithm(let algorithm):
            return "Unsupported proof-of-work algorithm: \(algorithm)"
        }
    }
}

struct AltchaSolvedPayload {
    let payload: String
    let elapsedMilliseconds: Int
}

enum AltchaSolver {
    static func solve(
        _ challenge: AltchaChallenge,
        timeoutSeconds: TimeInterval = 8,
        checkCancellationEvery iterationsBetweenChecks: Int = 25
    ) async throws -> AltchaSolvedPayload {
        let solverTask = Task.detached(priority: .userInitiated) {
            let parameters = try challenge.parameters()
            guard parameters.algorithm == "PBKDF2/SHA-256" else {
                throw AltchaSolverError.unsupportedAlgorithm(parameters.algorithm)
            }
            guard parameters.cost > 0, parameters.keyLength > 0 else {
                throw AltchaSolverError.invalidChallenge("ALTCHA challenge has invalid cost or key length.")
            }

            let nonce = try Data(hexString: parameters.nonce)
            let salt = try Data(hexString: parameters.salt)
            let startedAt = Date()
            var counter = 0

            while true {
                if counter % iterationsBetweenChecks == 0 {
                    try Task.checkCancellation()
                    if Date().timeIntervalSince(startedAt) > timeoutSeconds {
                        throw AltchaSolverError.timeout
                    }
                    if let maxNumber = parameters.maxNumber, counter > maxNumber {
                        throw AltchaSolverError.invalidChallenge("ALTCHA challenge could not be solved within its allowed range.")
                    }
                    if counter > Int(UInt32.max) {
                        throw AltchaSolverError.invalidChallenge("ALTCHA challenge exceeded the supported counter range.")
                    }
                }

                var password = nonce
                password.append(UInt32(counter).bigEndianData)
                let derivedKey = pbkdf2SHA256(
                    password: password,
                    salt: salt,
                    iterations: parameters.cost,
                    keyLength: parameters.keyLength
                )
                let derivedHex = derivedKey.hexString
                if derivedHex.hasPrefix(parameters.keyPrefix.lowercased()) {
                    let elapsed = Int(Date().timeIntervalSince(startedAt) * 1000)
                    let solution = AltchaSolution(
                        counter: counter,
                        derivedKey: derivedHex,
                        time: elapsed
                    )
                    let envelope = AltchaPayloadEnvelope(challenge: challenge.rawValue, solution: solution)
                    let data = try JSONEncoder().encode(envelope)
                    return AltchaSolvedPayload(payload: data.base64EncodedString(), elapsedMilliseconds: elapsed)
                }

                counter += 1
            }
        }

        return try await withTaskCancellationHandler {
            try await solverTask.value
        } onCancel: {
            solverTask.cancel()
        }
    }

    private static func pbkdf2SHA256(
        password: Data,
        salt: Data,
        iterations: Int,
        keyLength: Int
    ) -> Data {
        let hashLength = SHA256.byteCount
        let blockCount = Int(ceil(Double(keyLength) / Double(hashLength)))
        var output = Data()

        for blockIndex in 1...blockCount {
            var blockSalt = salt
            blockSalt.append(UInt32(blockIndex).bigEndianData)

            var u = hmacSHA256(key: password, message: blockSalt)
            var t = u

            if iterations > 1 {
                for _ in 1..<iterations {
                    u = hmacSHA256(key: password, message: u)
                    t.xorInPlace(with: u)
                }
            }

            output.append(t)
        }

        return output.prefixData(keyLength)
    }

    private static func hmacSHA256(key: Data, message: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let code = HMAC<SHA256>.authenticationCode(for: message, using: symmetricKey)
        return Data(code)
    }
}

private extension UInt32 {
    var bigEndianData: Data {
        var value = bigEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}

private extension Data {
    init(hexString: String) throws {
        let trimmed = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count % 2 == 0 else {
            throw AltchaSolverError.invalidChallenge("ALTCHA challenge contains invalid hex data.")
        }

        var data = Data(capacity: trimmed.count / 2)
        var index = trimmed.startIndex
        while index < trimmed.endIndex {
            let nextIndex = trimmed.index(index, offsetBy: 2)
            let byteString = trimmed[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else {
                throw AltchaSolverError.invalidChallenge("ALTCHA challenge contains invalid hex data.")
            }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    mutating func xorInPlace(with other: Data) {
        let count = Swift.min(self.count, other.count)
        for index in 0..<count {
            self[index] ^= other[index]
        }
    }

    func prefixData(_ count: Int) -> Data {
        Data(prefix(count))
    }
}
