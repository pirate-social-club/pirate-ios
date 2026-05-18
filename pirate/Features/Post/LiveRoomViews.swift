import SwiftUI
#if canImport(AgoraRtcKit) && os(iOS)
import AVFoundation
import AgoraRtcKit
import Combine
import UIKit
#endif

struct LiveRoomBannerView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii

    let post: Post
    let accessResponse: LiveRoomAccessResponse?
    let isLoading: Bool
    let isAttaching: Bool
    let errorMessage: String?
    let onRefresh: () -> Void
    let onWatch: () -> Void
    let onBuyTicket: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(statusTint)
                    .frame(width: 34, height: 34)
                    .background(colors.surfaceSubtle, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(2)
                    Text(detail)
                        .font(PirateTokens.Typography.small)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(3)
                }

                Spacer()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.accentDanger)
            }

            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(colors.accentBrand)
                }

                if let action = action {
                    Button {
                        switch action {
                        case .watch:
                            onWatch()
                        case .buy:
                            onBuyTicket()
                        case .signIn:
                            onSignIn()
                        case .refresh:
                            onRefresh()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isAttaching {
                                ProgressView()
                                    .tint(colors.textOnAccent)
                            } else {
                                Image(systemName: action.icon)
                            }
                            Text(isAttaching ? "Connecting..." : action.label)
                        }
                        .font(PirateTokens.Typography.smallStrong)
                        .foregroundStyle(colors.textOnAccent)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                    }
                    .buttonStyle(.plain)
                    .disabled(isAttaching)
                    .opacity(isAttaching ? 0.65 : 1)
                }

                Spacer()
            }
        }
        .padding(14)
        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.lg))
        .overlay(RoundedRectangle(cornerRadius: radii.lg).stroke(colors.borderSoft, lineWidth: 1))
    }

    private var room: LiveRoom? { accessResponse?.room }
    private var access: LiveRoomAccess? { accessResponse?.access }
    private var status: String { room?.status ?? post.anchorLiveRoomStatus ?? "scheduled" }

    private var title: String {
        room?.title ?? post.title ?? "Live room"
    }

    private var detail: String {
        if isLoading && accessResponse == nil {
            return "Checking live room access."
        }
        if let reason = access?.decisionReason {
            switch reason {
            case "purchase_required":
                return "A ticket is required to watch this live room."
            case "membership_required":
                return "Join this community before watching."
            case "not_live":
                return "Come back when the host goes live."
            case "ended":
                return "This live room has ended."
            case "canceled":
                return "This live room was canceled."
            default:
                return "This live room is not available right now."
            }
        }
        switch status {
        case "live":
            return "Watch the live broadcast from this post."
        case "ended":
            return "This live room has ended."
        case "canceled":
            return "This live room was canceled."
        default:
            return "Come back when the host goes live."
        }
    }

    private var statusIcon: String {
        switch status {
        case "live": return "dot.radiowaves.left.and.right"
        case "ended", "canceled": return "video.slash"
        default: return "calendar"
        }
    }

    private var statusTint: Color {
        switch status {
        case "live": return colors.accentDanger
        case "ended", "canceled": return colors.textSecondary
        default: return colors.accentBrand
        }
    }

    private var action: LiveRoomBannerAction? {
        if access?.allowed == true && status == "live" {
            return .watch
        }
        if access?.decisionReason == "purchase_required" {
            return .buy
        }
        if access?.decisionReason == "membership_required" {
            return .signIn
        }
        if access == nil || errorMessage != nil {
            return .refresh
        }
        return nil
    }
}

private enum LiveRoomBannerAction {
    case watch
    case buy
    case signIn
    case refresh

    var label: String {
        switch self {
        case .watch: return "Watch live"
        case .buy: return "Buy ticket"
        case .signIn: return "Sign in"
        case .refresh: return "Refresh"
        }
    }

    var icon: String {
        switch self {
        case .watch: return "play.fill"
        case .buy: return "ticket"
        case .signIn: return "person.crop.circle"
        case .refresh: return "arrow.clockwise"
        }
    }
}

struct LiveRoomViewerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.pirateColors) private var colors

    let attachResponse: LiveRoomViewerAttachResponse
    let onRenew: (UInt) async throws -> LiveRoomViewerAttachResponse

    var body: some View {
        LiveRoomViewerContent(
            attachResponse: attachResponse,
            onRenew: onRenew,
            onClose: { dismiss() }
        )
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                dismiss()
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

#if canImport(AgoraRtcKit) && os(iOS)
private struct LiveRoomViewerContent: View {
    @StateObject private var controller = LiveRoomAgoraController()

    let attachResponse: LiveRoomViewerAttachResponse
    let onRenew: (UInt) async throws -> LiveRoomViewerAttachResponse
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let remoteUid = controller.remoteUid, let engine = controller.engine {
                AgoraRemoteVideoView(engine: engine, uid: remoteUid)
                    .ignoresSafeArea()
            } else {
                LiveRoomViewerStatusView(status: controller.status, errorMessage: controller.errorMessage)
            }

            Button {
                controller.leave()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .padding(.trailing, 16)
        }
        .onAppear {
            controller.join(attachResponse: attachResponse, onRenew: onRenew)
        }
        .onDisappear {
            controller.leave()
        }
    }
}

private final class LiveRoomAgoraController: NSObject, ObservableObject, AgoraRtcEngineDelegate {
    @Published var status: String = "Connecting to the live room."
    @Published var errorMessage: String?
    @Published var remoteUid: UInt?

    private(set) var engine: AgoraRtcEngineKit?
    private var attachResponse: LiveRoomViewerAttachResponse?
    private var onRenew: ((UInt) async throws -> LiveRoomViewerAttachResponse)?
    private var didLeave = false
    private var isRenewing = false

    func join(
        attachResponse: LiveRoomViewerAttachResponse,
        onRenew: @escaping (UInt) async throws -> LiveRoomViewerAttachResponse
    ) {
        guard engine == nil else { return }
        self.attachResponse = attachResponse
        self.onRenew = onRenew

        let agora = attachResponse.agora
        guard agora.configured, let appId = agora.appId, let token = agora.token else {
            status = "Live playback is unavailable for this room."
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            errorMessage = error.localizedDescription
        }

        let config = AgoraRtcEngineConfig()
        config.appId = appId
        let engine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: self)
        self.engine = engine
        engine.setChannelProfile(.liveBroadcasting)
        engine.setClientRole(.audience)
        engine.enableVideo()

        status = "Connecting to the live room."
        engine.joinChannel(
            byToken: token,
            channelId: agora.channel,
            info: nil,
            uid: agora.uid
        ) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.status = "Connected. Waiting for the broadcaster."
            }
        }
    }

    func leave() {
        guard !didLeave else { return }
        didLeave = true
        remoteUid = nil
        engine?.leaveChannel(nil)
        engine = nil
        AgoraRtcEngineKit.destroy()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        DispatchQueue.main.async {
            self.remoteUid = uid
            self.status = "Watching live."
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        DispatchQueue.main.async {
            if self.remoteUid == uid {
                self.remoteUid = nil
                self.status = "Connected. Waiting for the broadcaster."
            }
        }
    }

    func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        Task { await renewToken() }
    }

    private func renewToken() async {
        guard !isRenewing, let attachResponse, let onRenew else { return }
        isRenewing = true
        defer { isRenewing = false }
        do {
            let renewed = try await onRenew(attachResponse.agora.uid)
            self.attachResponse = renewed
            if let token = renewed.agora.token {
                engine?.renewToken(token)
            }
        } catch {
            await setRenewalError(error.localizedDescription)
        }
    }

    @MainActor
    private func setRenewalError(_ message: String) {
        errorMessage = message
    }
}

private struct AgoraRemoteVideoView: UIViewRepresentable {
    let engine: AgoraRtcEngineKit
    let uid: UInt

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        setupVideo(in: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        setupVideo(in: uiView)
    }

    private func setupVideo(in view: UIView) {
        let canvas = AgoraRtcVideoCanvas()
        canvas.uid = uid
        canvas.view = view
        canvas.renderMode = .fit
        engine.setupRemoteVideo(canvas)
    }
}
#else
private struct LiveRoomViewerContent: View {
    let attachResponse: LiveRoomViewerAttachResponse
    let onRenew: (UInt) async throws -> LiveRoomViewerAttachResponse
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            LiveRoomViewerStatusView(
                status: "Live playback is unavailable in this build.",
                errorMessage: attachResponse.agora.configured ? nil : "Agora is not configured for this environment."
            )
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .padding(.trailing, 16)
        }
    }
}
#endif

private struct LiveRoomViewerStatusView: View {
    let status: String
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            Text(status)
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if let errorMessage {
                Text(errorMessage)
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(28)
        .frame(maxWidth: 360)
    }
}
