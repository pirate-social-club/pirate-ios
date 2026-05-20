import Foundation

struct VeryVerificationLaunchResult {
    let verified: Bool
    let verificationSessionId: String?
    let failureReason: String?
    let session: VerificationSession?
}

@MainActor
enum VeryVerificationLauncher {
    static func launch(verificationIntent: String) async -> VeryVerificationLaunchResult {
        debugLog("launch requested intent=\(verificationIntent) \(VeryNativeSdk.debugConfigurationSummary)")

        if !VeryNativeSdk.isConfigured() {
            debugLog("blocked before session start: VERY_SDK_KEY missing")
            return VeryVerificationLaunchResult(
                verified: false,
                verificationSessionId: nil,
                failureReason: "Native verification is not configured for this build. VERY_SDK_KEY is missing.",
                session: nil
            )
        }

        if !VeryNativeSdk.isSupported() {
            debugLog("blocked before session start: VerySDK reports unsupported device")
            return VeryVerificationLaunchResult(
                verified: false,
                verificationSessionId: nil,
                failureReason: "Very native verification is not supported on this device.",
                session: nil
            )
        }

        let createdSession: VerificationSession
        do {
            debugLog("starting native_sdk verification session")
            createdSession = try await ApiClient.shared.startVerificationSession(sessionRequest: StartVerificationSessionRequest(
                provider: "very",
                providerMode: "native_sdk",
                requestedCapabilities: nil,
                verificationIntent: verificationIntent
            ))
            debugLog(
                "created session id=\(createdSession.id) status=\(createdSession.status ?? "nil") providerMode=\(createdSession.providerMode ?? "nil") launchMode=\(launchMode(from: createdSession) ?? "nil")"
            )
        } catch let error as ApiError {
            debugLog("session start failed: \(error.diagnosticMessage)")
            return VeryVerificationLaunchResult(
                verified: false,
                verificationSessionId: nil,
                failureReason: failureMessage(for: error),
                session: nil
            )
        } catch {
            debugLog("session start failed: \(error.localizedDescription)")
            return VeryVerificationLaunchResult(
                verified: false,
                verificationSessionId: nil,
                failureReason: error.localizedDescription,
                session: nil
            )
        }

        guard createdSession.providerMode == "native_sdk",
              launchMode(from: createdSession) == "native_sdk" else {
            debugLog("session rejected: server did not return native_sdk launch")
            return VeryVerificationLaunchResult(
                verified: false,
                verificationSessionId: createdSession.id,
                failureReason: "Server did not return a native_sdk session. Native verification is unavailable.",
                session: createdSession
            )
        }

        debugLog("starting VerySDK.authenticate")
        let nativeResult = await VeryNativeSdk.authenticate()
        debugLog(
            "VerySDK result success=\(nativeResult.isSuccess) hasSignedToken=\((nativeResult.signedToken?.isEmpty == false)) hasUserId=\((nativeResult.userId?.isEmpty == false)) error=\(nativeResult.errorMessage ?? "nil")"
        )
        let signedToken = nativeResult.signedToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard nativeResult.isSuccess, let signedToken, !signedToken.isEmpty else {
            return VeryVerificationLaunchResult(
                verified: false,
                verificationSessionId: createdSession.id,
                failureReason: nativeResult.errorMessage ?? "Very native verification did not return a signed token.",
                session: createdSession
            )
        }

        do {
            debugLog("completing session id=\(createdSession.id) with signed_token")
            let completedSession = try await ApiClient.shared.completeVerificationSession(
                id: createdSession.id,
                request: CompleteVerificationSessionRequest(
                    providerPayloadRef: .object([
                        "mode": .string("native_sdk"),
                        "signed_token": .string(signedToken)
                    ])
                )
            )
            let verified = completedSession.status?.caseInsensitiveCompare("verified") == .orderedSame
            debugLog("completed session id=\(completedSession.id) status=\(completedSession.status ?? "nil") verified=\(verified)")
            return VeryVerificationLaunchResult(
                verified: verified,
                verificationSessionId: completedSession.id,
                failureReason: verified ? nil : "Very verification is still pending. Check status in a moment.",
                session: completedSession
            )
        } catch let error as ApiError {
            debugLog("session complete failed: \(error.diagnosticMessage)")
            return VeryVerificationLaunchResult(
                verified: false,
                verificationSessionId: createdSession.id,
                failureReason: failureMessage(for: error),
                session: createdSession
            )
        } catch {
            debugLog("session complete failed: \(error.localizedDescription)")
            return VeryVerificationLaunchResult(
                verified: false,
                verificationSessionId: createdSession.id,
                failureReason: error.localizedDescription,
                session: createdSession
            )
        }
    }

    private static func launchMode(from session: VerificationSession) -> String? {
        guard let launch = session.launch else { return nil }
        return launch.firstStringValue(named: "mode")
    }

    private static func failureMessage(for error: ApiError) -> String {
        #if DEBUG
        return error.diagnosticMessage
        #else
        return error.displayMessage
        #endif
    }

    private static func debugLog(_ message: String) {
        #if DEBUG
        NSLog("[VeryVerificationLauncher] %@", message)
        #endif
    }
}
