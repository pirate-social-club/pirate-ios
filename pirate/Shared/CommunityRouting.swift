import Foundation

private let punycodeBase = 36
private let punycodeTMin = 1
private let punycodeTMax = 26
private let punycodeInitialBias = 72
private let punycodeInitialN = 128

func formatCommunityRouteLabel(communityId: String, routeSlug: String? = nil) -> String {
    let trimmedRouteSlug = routeSlug?.trimmingCharacters(in: .whitespacesAndNewlines)
    let source = trimmedRouteSlug?.isEmpty == false ? trimmedRouteSlug! : communityId
    let routeSegment = formatCommunityRouteSegment(source)
    return routeSegment.lowercased().hasPrefix("c/") ? routeSegment : "c/\(routeSegment)"
}

private func formatCommunityRouteSegment(_ value: String) -> String {
    let trimmedInput = value.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmed = trimmedInput.lowercased().hasPrefix("c/")
        ? String(trimmedInput.dropFirst(2))
        : trimmedInput
    guard !trimmed.isEmpty else { return "community" }

    if trimmed.hasPrefix("@") {
        return "@\(decodePunycodeLabel(String(trimmed.dropFirst())))"
    }

    return decodePunycodeLabel(trimmed)
}

private func decodePunycodeLabel(_ value: String) -> String {
    guard value.lowercased().hasPrefix("xn--") else { return value }
    do {
        return try decodePunycode(String(value.dropFirst(4)))
    } catch {
        return value
    }
}

private func decodePunycode(_ input: String) throws -> String {
    let scalars = input.unicodeScalars.map { Int($0.value) }
    var output: [Int] = []
    var n = punycodeInitialN
    var i = 0
    var bias = punycodeInitialBias
    let basicEnd = scalars.lastIndex(of: 45)

    if let basicEnd {
        for index in 0..<basicEnd {
            guard scalars[index] < 0x80 else { throw PunycodeError.invalidInput }
            output.append(scalars[index])
        }
    }

    var index = basicEnd.map { $0 + 1 } ?? 0
    while index < scalars.count {
        let oldI = i
        var w = 1
        var k = punycodeBase

        while true {
            guard index < scalars.count else { throw PunycodeError.invalidInput }
            let digit = decodePunycodeDigit(scalars[index])
            index += 1
            guard digit < punycodeBase else { throw PunycodeError.invalidInput }
            i += digit * w
            let t: Int
            if k <= bias {
                t = punycodeTMin
            } else if k >= bias + punycodeTMax {
                t = punycodeTMax
            } else {
                t = k - bias
            }
            if digit < t { break }
            w *= punycodeBase - t
            k += punycodeBase
        }

        let outputLength = output.count + 1
        bias = adaptPunycodeBias(deltaInput: i - oldI, numPoints: outputLength, firstTime: oldI == 0)
        n += i / outputLength
        i %= outputLength
        output.insert(n, at: i)
        i += 1
    }

    var view = String.UnicodeScalarView()
    for value in output {
        guard let scalar = UnicodeScalar(value) else { throw PunycodeError.invalidInput }
        view.append(scalar)
    }
    return String(view)
}

private func decodePunycodeDigit(_ codePoint: Int) -> Int {
    switch codePoint {
    case 48...57:
        return codePoint - 48 + 26
    case 65...90:
        return codePoint - 65
    case 97...122:
        return codePoint - 97
    default:
        return punycodeBase
    }
}

private func adaptPunycodeBias(deltaInput: Int, numPoints: Int, firstTime: Bool) -> Int {
    var delta = firstTime ? deltaInput / 700 : deltaInput / 2
    delta += delta / numPoints
    var k = 0
    while delta > ((punycodeBase - punycodeTMin) * punycodeTMax) / 2 {
        delta /= punycodeBase - punycodeTMin
        k += punycodeBase
    }
    return k + (((punycodeBase - punycodeTMin + 1) * delta) / (delta + 38))
}

private enum PunycodeError: Error {
    case invalidInput
}
