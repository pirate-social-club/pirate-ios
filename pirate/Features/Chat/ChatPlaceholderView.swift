import SwiftUI

@MainActor
struct ChatPlaceholderView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii

    var sessionManager: SessionManager
    var initialTarget: String? = nil
    @State private var chatService = XmtpChatService.shared
    @State private var mode: ChatMode = .conversations
    @State private var newDmTarget = ""
    @State private var newGroupName = ""
    @State private var newGroupMembers = ""
    @State private var draftMessage = ""
    @State private var actionInFlight = false
    @State private var errorMessage: String?
    @State private var didOpenInitialTarget = false

    init(sessionManager: SessionManager, initialTarget: String? = nil) {
        self.sessionManager = sessionManager
        self.initialTarget = initialTarget
    }

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            Group {
                switch mode {
                case .conversations:
                    conversationList
                case .thread:
                    threadView
                case .newDm:
                    newDmView
                case .newGroup:
                    newGroupView
                }
            }
            .background(colors.bgPage)
            .hiddenRootNavigationBar()
            .task(id: "\(sessionManager.primaryWalletAddress ?? ""):\(initialTarget ?? "")") {
                await bootstrap()
                await openInitialTargetIfNeeded()
            }
            .onAppear {
                chatService.setChatVisible(true)
            }
            .onDisappear {
                chatService.setChatVisible(false)
            }
            .refreshable {
                await refresh()
            }
        }
    }

    private var conversationList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                MobilePageHeader("Chat") {
                    headerIconButton(icon: .chatCircle, label: "New message") {
                        mode = .newDm
                    }
                    .disabled(!chatService.isConnected || actionInFlight)

                    headerIconButton(icon: .users, label: "New group") {
                        mode = .newGroup
                    }
                    .disabled(!chatService.isConnected || actionInFlight)
                }

                if let errorMessage {
                    errorBanner(errorMessage)
                }

                if chatService.isConnecting {
                    LoadingView()
                        .frame(height: 180)
                } else if chatService.conversations.isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right",
                        title: chatService.isConnected ? "No messages yet" : "Messages unavailable",
                        subtitle: chatService.isConnected ? nil : chatService.lastErrorMessage
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                } else {
                    ForEach(chatService.conversations) { conversation in
                        Button {
                            Task { await openConversation(conversation.id) }
                        } label: {
                            conversationRow(conversation)
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(colors.borderSoft)
                    }
                }
            }
        }
    }

    private func headerIconButton(icon: PirateIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PirateIconView(icon: icon, size: 21, color: colors.textPrimary)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var threadView: some View {
        VStack(spacing: 0) {
            threadHeader
            Divider().overlay(colors.borderSoft)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(chatService.messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, PirateTokens.pageGutter)
                    .padding(.vertical, 12)
                }
                .onChange(of: chatService.messages) { _, messages in
                    guard let last = messages.last else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            Divider().overlay(colors.borderSoft)
            composer
        }
    }

    private var newDmView: some View {
        VStack(spacing: 16) {
            subpageHeader(title: "New Message")

            TextField("Address, inbox, or handle", text: $newDmTarget)
                .textFieldStyle(.plain)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)
                .padding(12)
                .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
                .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif

            primaryActionButton(title: "Start", systemImage: "arrow.right", disabled: newDmTarget.trimmedForChat.isEmpty) {
                await createDm()
            }

            Spacer()
        }
        .padding(PirateTokens.pageGutter)
    }

    private var newGroupView: some View {
        VStack(spacing: 16) {
            subpageHeader(title: "New Group")

            TextField("Name", text: $newGroupName)
                .textFieldStyle(.plain)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)
                .padding(12)
                .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
                .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))

            TextEditor(text: $newGroupMembers)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(8)
                .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
                .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))

            primaryActionButton(title: "Create", systemImage: "person.2.badge.plus", disabled: parsedGroupMembers.isEmpty) {
                await createGroup()
            }

            Spacer()
        }
        .padding(PirateTokens.pageGutter)
    }

    private var threadHeader: some View {
        let active = chatService.conversations.first { $0.id == chatService.activeConversationId }
        return HStack(spacing: 12) {
            Button {
                chatService.closeConversation()
                mode = .conversations
            } label: {
                PirateSystemIconView(systemName: "chevron.left", size: 18)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(colors.textPrimary)
            }
            .buttonStyle(.plain)

            conversationAvatar(active)

            VStack(alignment: .leading, spacing: 2) {
                Text(active?.displayName ?? "Conversation")
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textPrimary)
                    .lineLimit(1)

                if let subtitle = active?.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(PirateTokens.Typography.small)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if let address = active?.peerAddress, XmtpAddressing.looksLikeEthereumAddress(address) {
                NavigationLink(value: PirateRoute.publicProfileByWallet(address)) {
                    PirateSystemIconView(systemName: "person.crop.circle", size: 20)
                        .font(.system(size: 20))
                        .foregroundStyle(colors.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 10)
        .background(colors.bgPage)
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $draftMessage, axis: .vertical)
                .textFieldStyle(.plain)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.x2l))
                .overlay(RoundedRectangle(cornerRadius: radii.x2l).stroke(colors.borderSoft, lineWidth: 1))

            Button {
                Task { await sendMessage() }
            } label: {
                PirateSystemIconView(systemName: "paperplane.fill", size: 17)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(colors.textOnAccent)
                    .frame(width: 42, height: 42)
                    .background(colors.accentBrand, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(draftMessage.trimmedForChat.isEmpty || actionInFlight)
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 10)
        .background(colors.bgPage)
    }

    private func conversationRow(_ conversation: XmtpConversationItem) -> some View {
        HStack(spacing: 12) {
            conversationAvatar(conversation)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(conversation.displayName)
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if let date = conversation.lastMessageDate {
                        Text(date.formatted(.relative(presentation: .numeric)))
                            .font(PirateTokens.Typography.small)
                            .foregroundStyle(colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Text(conversation.lastMessage.isEmpty ? (conversation.subtitle ?? "") : conversation.lastMessage)
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func conversationAvatar(_ conversation: XmtpConversationItem?) -> some View {
        if conversation?.kind == .group {
            Circle()
                .fill(colors.surfaceSubtle)
                .frame(width: 42, height: 42)
                .overlay(
                    PirateSystemIconView(systemName: "person.2.fill", size: 18)
                        .font(.system(size: 18))
                        .foregroundStyle(colors.accentBrand)
                )
        } else {
            AvatarView(avatarRef: conversation?.avatarRef, size: 42)
        }
    }

    private func messageBubble(_ message: XmtpChatMessage) -> some View {
        HStack {
            if message.isFromMe {
                Spacer(minLength: 44)
            }

            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(message.isFromMe ? colors.textOnAccent : colors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        message.isFromMe ? colors.accentBrand : colors.bgElevated,
                        in: RoundedRectangle(cornerRadius: radii.x2l)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radii.x2l)
                            .stroke(message.isFromMe ? Color.clear : colors.borderSoft, lineWidth: 1)
                    )

                Text(message.sentAt.formatted(date: .omitted, time: .shortened))
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.textSecondary)
            }

            if !message.isFromMe {
                Spacer(minLength: 44)
            }
        }
    }

    private func subpageHeader(title: String) -> some View {
        HStack(spacing: 12) {
            Button {
                mode = .conversations
            } label: {
                PirateSystemIconView(systemName: "chevron.left", size: 18)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(colors.textPrimary)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(PirateTokens.Typography.h4)
                .foregroundStyle(colors.textPrimary)

            Spacer()
        }
    }

    private func primaryActionButton(
        title: String,
        systemImage: String,
        disabled: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack(spacing: 8) {
                if actionInFlight {
                    ProgressView()
                        .tint(colors.textOnAccent)
                } else {
                    PirateSystemIconView(systemName: systemImage)
                }
                Text(title)
                    .font(PirateTokens.Typography.bodyStrong)
            }
            .foregroundStyle(colors.textOnAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(disabled ? colors.surfaceDisabled : colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
        }
        .buttonStyle(.plain)
        .disabled(disabled || actionInFlight)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            PirateSystemIconView(systemName: "exclamationmark.triangle")
                .foregroundStyle(colors.accentWarning)
            Text(message)
                .font(PirateTokens.Typography.small)
                .foregroundStyle(colors.textSecondary)
                .lineLimit(2)
            Spacer()
            Button {
                errorMessage = nil
            } label: {
                PirateSystemIconView(systemName: "xmark")
                    .foregroundStyle(colors.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 10)
        .background(colors.surfaceWarning.opacity(0.15))
    }

    private var parsedGroupMembers: [String] {
        newGroupMembers
            .split { $0 == "," || $0 == "\n" || $0 == " " || $0 == "\t" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func bootstrap() async {
        guard sessionManager.isAuthenticated else {
            chatService.disconnect()
            return
        }
        guard let walletAddress = sessionManager.primaryWalletAddress else {
            errorMessage = XmtpChatServiceError.missingWalletAddress.localizedDescription
            return
        }

        do {
            try await chatService.connect(walletAddress: walletAddress)
            try await publishInboxIfNeeded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func publishInboxIfNeeded() async throws {
        guard let inboxId = chatService.currentInboxId else { return }
        guard sessionManager.profile?.xmtpInbox != inboxId else { return }
        _ = try await ApiClient.shared.publishXmtpInbox(inboxId)
        await sessionManager.refreshProfile()
    }

    private func refresh() async {
        do {
            try await chatService.refreshConversations()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openConversation(_ id: String) async {
        do {
            try await chatService.openConversation(id)
            mode = .thread
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func openInitialTargetIfNeeded() async {
        guard !didOpenInitialTarget else { return }
        guard let target = initialTarget?.trimmedForChat, !target.isEmpty else { return }
        guard chatService.isConnected else { return }
        didOpenInitialTarget = true
        await runAction {
            let id = try await chatService.newDm(target)
            try await chatService.openConversation(id)
            mode = .thread
        }
    }

    private func createDm() async {
        let target = newDmTarget.trimmedForChat
        guard !target.isEmpty else { return }
        await runAction {
            let id = try await chatService.newDm(target)
            try await chatService.openConversation(id)
            newDmTarget = ""
            mode = .thread
        }
    }

    private func createGroup() async {
        let members = parsedGroupMembers
        guard !members.isEmpty else { return }
        await runAction {
            let id = try await chatService.newGroup(memberTargets: members, name: newGroupName)
            try await chatService.openConversation(id)
            newGroupName = ""
            newGroupMembers = ""
            mode = .thread
        }
    }

    private func sendMessage() async {
        let message = draftMessage.trimmedForChat
        guard !message.isEmpty else { return }
        draftMessage = ""
        await runAction {
            try await chatService.sendMessage(message)
        }
    }

    private func runAction(_ action: () async throws -> Void) async {
        actionInFlight = true
        errorMessage = nil
        defer { actionInFlight = false }
        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum ChatMode {
    case conversations
    case thread
    case newDm
    case newGroup
}

private extension String {
    var trimmedForChat: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
