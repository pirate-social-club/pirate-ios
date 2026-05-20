import Foundation

#if os(iOS)
import UIKit
#endif

#if os(iOS) && canImport(VerySDK)
import VerySDK
#endif

struct VeryNativeAuthenticationResult {
    let isSuccess: Bool
    let signedToken: String?
    let userId: String?
    let errorMessage: String?
}

@MainActor
enum VeryNativeSdk {
    static var sdkKey: String {
        sdkKeyCandidate().key
    }

    static var debugConfigurationSummary: String {
        let candidate = sdkKeyCandidate()
        return "sdkLinked=\(isSdkLinked) configured=\(!candidate.key.isEmpty) keySource=\(candidate.source) keyLength=\(candidate.key.count)"
    }

    private static var isSdkLinked: Bool {
        #if os(iOS) && canImport(VerySDK)
        return true
        #else
        return false
        #endif
    }

    private static func sdkKeyCandidate() -> (key: String, source: String) {
        let environmentKey = ProcessInfo.processInfo.environment["VERY_SDK_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let environmentKey, !environmentKey.isEmpty {
            return (environmentKey, "environment")
        }

        let bundleKey = Bundle.main.object(forInfoDictionaryKey: "VERY_SDK_KEY") as? String
        let trimmedBundleKey = bundleKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedBundleKey.isEmpty, !trimmedBundleKey.contains("$(") {
            return (trimmedBundleKey, "Info.plist")
        }

        let generatedKey = generatedSecretsSdkKey
        return (generatedKey, generatedKey.isEmpty ? "missing" : "VerySecrets.plist")
    }

    private static var generatedSecretsSdkKey: String {
        guard let url = Bundle.main.url(forResource: "VerySecrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dictionary = plist as? [String: Any],
              let sdkKey = dictionary["VERY_SDK_KEY"] as? String else {
            return ""
        }
        return sdkKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isConfigured() -> Bool {
        !sdkKey.isEmpty
    }

    static func isSupported() -> Bool {
        guard isConfigured() else { return false }
        #if os(iOS) && canImport(VerySDK)
        return VerySDK.isSupported()
        #else
        return false
        #endif
    }

    static func unavailableMessage() -> String {
        if !isConfigured() {
            return "Native palm verification is not configured for this build. VERY_SDK_KEY is missing."
        }
        #if os(iOS) && canImport(VerySDK)
        return "Very native verification is not supported on this device."
        #else
        return "Very native verification is not available in this build."
        #endif
    }

    static func authenticate(userId: String? = nil) async -> VeryNativeAuthenticationResult {
        guard isSupported() else {
            return VeryNativeAuthenticationResult(
                isSuccess: false,
                signedToken: nil,
                userId: nil,
                errorMessage: unavailableMessage()
            )
        }

        #if os(iOS) && canImport(VerySDK)
        guard let presenter = UIApplication.shared.pirateTopViewController else {
            return VeryNativeAuthenticationResult(
                isSuccess: false,
                signedToken: nil,
                userId: nil,
                errorMessage: "Very native verification needs an active screen."
            )
        }

        let config = VeryConfig(
            sdkKey: sdkKey,
            userId: userId,
            language: "en",
            themeMode: "dark",
            debugLogging: ProcessInfo.processInfo.environment["PIRATE_VERY_SDK_DEBUG_LOGGING"] == "1"
        )

        return await withCheckedContinuation { continuation in
            VerySDK.authenticate(from: presenter, config: config) { result in
                if result.isSuccess {
                    continuation.resume(returning: VeryNativeAuthenticationResult(
                        isSuccess: true,
                        signedToken: result.signedToken?.trimmingCharacters(in: .whitespacesAndNewlines),
                        userId: result.userId.trimmingCharacters(in: .whitespacesAndNewlines),
                        errorMessage: nil
                    ))
                    return
                }

                let message = result.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? result.error?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? "Very native verification was not completed."
                continuation.resume(returning: VeryNativeAuthenticationResult(
                    isSuccess: false,
                    signedToken: nil,
                    userId: result.userId.trimmingCharacters(in: .whitespacesAndNewlines),
                    errorMessage: message
                ))
            }
        }
        #else
        return VeryNativeAuthenticationResult(
            isSuccess: false,
            signedToken: nil,
            userId: nil,
            errorMessage: unavailableMessage()
        )
        #endif
    }
}

#if os(iOS)
private extension UIApplication {
    var pirateTopViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .pirateTopPresentedViewController
    }
}

private extension UIViewController {
    var pirateTopPresentedViewController: UIViewController {
        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.pirateTopPresentedViewController
        }
        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.pirateTopPresentedViewController
        }
        if let presentedViewController {
            return presentedViewController.pirateTopPresentedViewController
        }
        return self
    }
}
#endif
