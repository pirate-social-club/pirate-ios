import SwiftUI
#if canImport(AgoraRtcKit) && os(iOS)
import AVFoundation
import AgoraRtcKit
import Combine
import UIKit
#endif

struct LiveRoomPostContentView: View {
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
        let presentation = LiveRoomPresentation(post: post, accessResponse: accessResponse, loadErrorMessage: errorMessage)

        VStack(alignment: .leading, spacing: 14) {
            cover(for: presentation)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(presentation.title)
                        .font(PirateTokens.Typography.h3)
                        .foregroundStyle(colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    statusPill(for: presentation)
                }

                Spacer(minLength: 0)

                if let action = presentation.primaryAction {
                    actionButton(action, presentation: presentation)
                }
            }

            Text(isLoading && accessResponse == nil ? "Checking live room access." : presentation.description)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let message = presentation.loadErrorMessage {
                Text(message)
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.accentDanger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let body = presentation.body, body != presentation.title {
                Text(body)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let room = accessResponse?.room, !room.setlist.items.isEmpty {
                setlistPreview(room.setlist.items)
            }
        }
    }

    @ViewBuilder
    private func cover(for presentation: LiveRoomPresentation) -> some View {
        ZStack {
            if let coverURL = presentation.coverURL {
                AsyncImage(url: coverURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        coverFallback
                    case .empty:
                        ZStack {
                            colors.bgElevated
                            ProgressView().tint(colors.accentBrand)
                        }
                    @unknown default:
                        coverFallback
                    }
                }
            } else {
                coverFallback
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: radii.lg))
        .overlay(RoundedRectangle(cornerRadius: radii.lg).stroke(colors.borderSoft, lineWidth: 1))
        .clipped()
    }

    private var coverFallback: some View {
        ZStack {
            colors.bgElevated
            PirateSystemIconView(systemName: "dot.radiowaves.left.and.right", size: 42)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(colors.textSecondary)
        }
    }

    private func statusPill(for presentation: LiveRoomPresentation) -> some View {
        HStack(spacing: 6) {
            PirateSystemIconView(systemName: presentation.statusIcon, size: 13)
                .font(.system(size: 13, weight: .semibold))
            Text(presentation.statusLabel)
                .font(PirateTokens.Typography.smallStrong)
        }
        .foregroundStyle(statusTint(for: presentation))
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(statusBackground(for: presentation), in: RoundedRectangle(cornerRadius: radii.full))
        .overlay(RoundedRectangle(cornerRadius: radii.full).stroke(colors.borderSoft, lineWidth: 1))
    }

    private func actionButton(_ action: LiveRoomPresentation.PrimaryAction, presentation: LiveRoomPresentation) -> some View {
        Button {
            switch action {
            case .watch:
                onWatch()
            case .buyTicket:
                onBuyTicket()
            case .signIn:
                onSignIn()
            case .refresh:
                onRefresh()
            }
        } label: {
            HStack(spacing: 8) {
                if isAttaching {
                    ProgressView().tint(colors.textOnAccent)
                } else {
                    PirateSystemIconView(systemName: action.icon)
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

    private func setlistPreview(_ items: [LiveRoomSetlistItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Setlist")
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textPrimary)
                Text("\(items.count) songs")
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.full))
            }

            ForEach(items.prefix(3)) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(item.position).")
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.textSecondary)
                        .monospacedDigit()
                    Text(item.artist.map { "\(item.title) - \($0)" } ?? item.title)
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(12)
        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
        .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))
    }

    private func statusTint(for presentation: LiveRoomPresentation) -> Color {
        switch presentation.status {
        case .live:
            return colors.accentDanger
        case .ended, .canceled:
            return colors.textSecondary
        default:
            return colors.accentBrand
        }
    }

    private func statusBackground(for presentation: LiveRoomPresentation) -> Color {
        presentation.status == .live ? colors.surfaceDanger : colors.surfaceSubtle
    }
}

struct LiveRoomPresentation {
    enum Status {
        case scheduled
        case live
        case ended
        case canceled
        case unknown
    }

    enum AccessState {
        case allowed
        case purchaseRequired
        case membershipRequired
        case waiting
        case ended
        case canceled
        case unavailable
        case unknown
    }

    enum PrimaryAction {
        case watch
        case buyTicket
        case signIn
        case refresh

        var label: String {
            switch self {
            case .watch: return "Watch live"
            case .buyTicket: return "Buy ticket"
            case .signIn: return "Sign in"
            case .refresh: return "Refresh"
            }
        }

        var icon: String {
            switch self {
            case .watch: return "play.fill"
            case .buyTicket: return "ticket"
            case .signIn: return "person.crop.circle"
            case .refresh: return "arrow.clockwise"
            }
        }
    }

    let post: Post
    let accessResponse: LiveRoomAccessResponse?
    let loadErrorMessage: String?

    var room: LiveRoom? { accessResponse?.room }
    var access: LiveRoomAccess? { accessResponse?.access }

    var title: String {
        room?.title ?? post.title ?? "Live room"
    }

    var body: String? {
        room?.description ?? post.body
    }

    var status: Status {
        switch room?.status ?? post.anchorLiveRoomStatus {
        case "scheduled": return .scheduled
        case "live": return .live
        case "ended": return .ended
        case "canceled": return .canceled
        default: return .unknown
        }
    }

    var accessState: AccessState {
        if access?.allowed == true {
            return .allowed
        }

        switch access?.decisionReason {
        case "purchase_required": return .purchaseRequired
        case "membership_required": return .membershipRequired
        case "not_live": return .waiting
        case "ended": return .ended
        case "canceled": return .canceled
        case nil:
            return loadErrorMessage == nil ? .unknown : .unavailable
        default:
            return .unavailable
        }
    }

    var statusLabel: String {
        switch status {
        case .live: return "Live now"
        case .ended: return "Ended"
        case .canceled: return "Canceled"
        case .scheduled: return "Scheduled"
        case .unknown: return "Live room"
        }
    }

    var description: String {
        if loadErrorMessage != nil {
            return accessResponse == nil ? "Live room details could not be loaded." : stateDescription
        }
        return stateDescription
    }

    private var stateDescription: String {
        switch accessState {
        case .purchaseRequired:
            return "A ticket is required to watch this live room."
        case .membershipRequired:
            return "Join this community before watching."
        case .waiting:
            return "Come back when the host goes live."
        case .ended:
            return "Ended"
        case .canceled:
            return "Canceled"
        case .unavailable:
            return "This live room is not available right now."
        case .allowed, .unknown:
            switch status {
            case .live:
                return "Watch the live broadcast from this post."
            case .ended:
                return "Ended"
            case .canceled:
                return "Canceled"
            case .scheduled, .unknown:
                return "Come back when the host goes live."
            }
        }
    }

    var statusIcon: String {
        switch status {
        case .live: return "dot.radiowaves.left.and.right"
        case .ended: return "checkmark.circle"
        case .canceled: return "xmark"
        case .scheduled, .unknown: return "calendar"
        }
    }

    var coverURL: URL? {
        ApiClient.shared.publicMediaURL(from: room?.coverRef)
            ?? PiratePostMediaItem.primary(for: post)?.previewURL
    }

    var primaryAction: PrimaryAction? {
        if loadErrorMessage != nil {
            return .refresh
        }
        if accessState == .allowed && status == .live {
            return .watch
        }
        if accessState == .purchaseRequired {
            return .buyTicket
        }
        if accessState == .membershipRequired {
            return .signIn
        }
        if accessResponse == nil && status != .ended && status != .canceled {
            return .refresh
        }
        return nil
    }
}

extension ApiError {
    var liveRoomDecisionReason: String? {
        guard case .object(let values) = details else { return nil }
        return values["decision_reason"]?.stringValue
    }

    var isResolvedLiveRoomUnavailable: Bool {
        switch liveRoomDecisionReason {
        case "not_live", "ended", "canceled":
            return true
        default:
            return false
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
            presentation: .fullScreen,
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

struct LiveRoomInlineViewerView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii

    let attachResponse: LiveRoomViewerAttachResponse
    let onRenew: (UInt) async throws -> LiveRoomViewerAttachResponse

    var body: some View {
        LiveRoomViewerContent(
            attachResponse: attachResponse,
            onRenew: onRenew,
            presentation: .inline,
            onClose: nil
        )
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: radii.lg))
        .overlay(RoundedRectangle(cornerRadius: radii.lg).stroke(colors.borderSoft, lineWidth: 1))
    }
}

private enum LiveRoomViewerPresentation {
    case fullScreen
    case inline
}

#if canImport(AgoraRtcKit) && os(iOS)
private struct LiveRoomViewerContent: View {
    @StateObject private var controller = LiveRoomAgoraController()

    let attachResponse: LiveRoomViewerAttachResponse
    let onRenew: (UInt) async throws -> LiveRoomViewerAttachResponse
    let presentation: LiveRoomViewerPresentation
    let onClose: (() -> Void)?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            background

            if let remoteUid = controller.remoteUid, let engine = controller.engine {
                remoteVideo(engine: engine, uid: remoteUid)
            } else {
                LiveRoomViewerStatusView(status: controller.status, errorMessage: controller.errorMessage)
            }

            if let onClose {
                Button {
                    controller.leave()
                    onClose()
                } label: {
                    PirateSystemIconView(systemName: "xmark", size: 16)
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
        .onAppear {
            controller.join(attachResponse: attachResponse, onRenew: onRenew)
        }
        .onDisappear {
            controller.leave()
        }
    }

    @ViewBuilder
    private var background: some View {
        switch presentation {
        case .fullScreen:
            Color.black.ignoresSafeArea()
        case .inline:
            Color.black
        }
    }

    @ViewBuilder
    private func remoteVideo(engine: AgoraRtcEngineKit, uid: UInt) -> some View {
        switch presentation {
        case .fullScreen:
            AgoraRemoteVideoView(engine: engine, uid: uid)
                .ignoresSafeArea()
        case .inline:
            AgoraRemoteVideoView(engine: engine, uid: uid)
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
    let presentation: LiveRoomViewerPresentation
    let onClose: (() -> Void)?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            switch presentation {
            case .fullScreen:
                Color.black.ignoresSafeArea()
            case .inline:
                Color.black
            }
            LiveRoomViewerStatusView(
                status: "Live playback is unavailable in this build.",
                errorMessage: attachResponse.agora.configured ? nil : "Agora is not configured for this environment."
            )
            if let onClose {
                Button {
                    onClose()
                } label: {
                    PirateSystemIconView(systemName: "xmark", size: 16)
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
}
#endif

private struct LiveRoomViewerStatusView: View {
    let status: String
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 14) {
            PirateSystemIconView(systemName: "dot.radiowaves.left.and.right", size: 42)
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
