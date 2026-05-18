import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

private let settingsDisplayNameMax = 50
private let settingsBioMax = 300

private struct ProfileMediaSelection {
    let data: Data
    let filename: String
    let mimeType: String
    let image: UIImage
}

struct SettingsView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    var sessionManager: SessionManager

    @State private var showSignOutConfirmation = false

    var body: some View {
        List {
            Section {
                NavigationLink(value: PirateRoute.settingsSection("profile")) {
                    Label("Profile", systemImage: "person")
                }
                NavigationLink(value: PirateRoute.settingsSection("preferences")) {
                    Label("Preferences", systemImage: "slider.horizontal.3")
                }
                NavigationLink(value: PirateRoute.settingsSection("domains")) {
                    Label("Domains", systemImage: "globe")
                }
                NavigationLink(value: PirateRoute.settingsSection("agents")) {
                    Label("Agents", systemImage: "cpu")
                }
            }

            Section {
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    Label("Sign Out", systemImage: "arrow.right.square")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(colors.bgPage)
        .navigationTitle("Settings")
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                Task { await sessionManager.logout() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

private func profileDisplayHandle(_ profile: Profile?) -> String? {
    guard let profile else { return nil }
    let label = profile.primaryPublicHandle?.label.nilIfEmpty ?? profile.globalHandle?.label.nilIfEmpty
    guard let label else { return nil }
    return label.contains(".") ? label : "\(label).pirate"
}

private struct SettingsDefaultCover: View {
    let displayName: String
    let userId: String

    private var pair: (Color, Color) {
        let seed = "\(userId):\(displayName):profile-cover"
        return settingsDefaultCoverColors[Int(settingsStableHash(seed) % UInt32(settingsDefaultCoverColors.count))]
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [pair.0, pair.1], startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 132, height: 132)
                .offset(x: 32, y: -18)

            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 72)
            }
        }
    }
}

private let settingsDefaultCoverColors: [(Color, Color)] = [
    (Color(red: 0x17 / 255.0, green: 0x4A / 255.0, blue: 0x53 / 255.0), Color(red: 0xB5 / 255.0, green: 0x6B / 255.0, blue: 0x34 / 255.0)),
    (Color(red: 0x51 / 255.0, green: 0x33 / 255.0, blue: 0x5F / 255.0), Color(red: 0x1F / 255.0, green: 0x7A / 255.0, blue: 0x6D / 255.0)),
    (Color(red: 0x25 / 255.0, green: 0x47 / 255.0, blue: 0x6A / 255.0), Color(red: 0x8A / 255.0, green: 0x3D / 255.0, blue: 0x4F / 255.0)),
    (Color(red: 0x5A / 255.0, green: 0x3F / 255.0, blue: 0x2B / 255.0), Color(red: 0x27 / 255.0, green: 0x63 / 255.0, blue: 0x5F / 255.0)),
    (Color(red: 0x6E / 255.0, green: 0x3A / 255.0, blue: 0x46 / 255.0), Color(red: 0x2E / 255.0, green: 0x5A / 255.0, blue: 0x77 / 255.0))
]

private func settingsStableHash(_ value: String) -> UInt32 {
    var hash: UInt32 = 2_166_136_261
    for scalar in value.unicodeScalars {
        hash ^= scalar.value
        hash = hash &* 16_777_619
    }
    return hash
}

struct SettingsSectionView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    var sessionManager: SessionManager
    let section: String

    @State private var displayName = ""
    @State private var bio = ""
    @State private var handleLabel = ""
    @State private var preferredLocale = ""
    @State private var pendingAvatar: ProfileMediaSelection?
    @State private var pendingCover: ProfileMediaSelection?
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var coverPickerItem: PhotosPickerItem?
    @State private var avatarRemoved = false
    @State private var coverRemoved = false
    @State private var displayNameError: String?
    @State private var handleExpanded = false
    @State private var isRenamingHandle = false
    @State private var isSaving = false
    @State private var message: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch section {
                case "profile":
                    profileSection
                case "preferences":
                    preferencesSection
                case "domains":
                    domainsSection
                case "agents":
                    agentsSection
                default:
                    Text("Unknown settings section.")
                        .font(PirateTokens.Typography.body)
                        .foregroundStyle(colors.textSecondary)
                }

                if let message {
                    Text(message)
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.accentSuccess)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.accentDanger)
                }
            }
            .padding(PirateTokens.pageGutter)
        }
        .background(colors.bgPage)
        .navigationTitle(sectionTitle)
        .onAppear {
            syncLocalStateFromProfile()
        }
        .onChange(of: avatarPickerItem) { _, item in
            Task { await loadPickedMedia(item, target: .avatar) }
        }
        .onChange(of: coverPickerItem) { _, item in
            Task { await loadPickedMedia(item, target: .cover) }
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            settingsSection("Appearance") {
                VStack(alignment: .leading, spacing: 20) {
                    mediaControl(
                        title: "Avatar",
                        shape: .avatar,
                        selectedLabel: pendingAvatar?.filename,
                        canRemove: !avatarRemoved && (sessionManager.profile?.avatarRef?.nilIfEmpty != nil || pendingAvatar != nil),
                        selectLabel: sessionManager.profile?.avatarRef?.nilIfEmpty != nil || pendingAvatar != nil ? "Replace avatar" : "Upload avatar",
                        removeLabel: "Remove avatar",
                        pickerSelection: $avatarPickerItem,
                        onRemove: removeAvatar
                    ) {
                        avatarPreview
                    }

                    mediaControl(
                        title: "Cover",
                        hint: "1500x500 recommended",
                        shape: .cover,
                        selectedLabel: pendingCover?.filename,
                        canRemove: !coverRemoved && (sessionManager.profile?.coverRef?.nilIfEmpty != nil || pendingCover != nil),
                        selectLabel: sessionManager.profile?.coverRef?.nilIfEmpty != nil || pendingCover != nil ? "Replace cover" : "Upload cover",
                        removeLabel: "Remove cover",
                        pickerSelection: $coverPickerItem,
                        onRemove: removeCover
                    ) {
                        coverPreview
                    }
                }
            }

            settingsSection("Profile") {
                VStack(alignment: .leading, spacing: 14) {
                    field(
                        "Display name",
                        text: Binding(
                            get: { displayName },
                            set: {
                                displayName = String($0.prefix(settingsDisplayNameMax))
                                displayNameError = nil
                                clearStatusMessages()
                            }
                        ),
                        counter: "\(displayName.count)/\(settingsDisplayNameMax)"
                    )

                    if let displayNameError {
                        Text(displayNameError)
                            .font(PirateTokens.Typography.caption)
                            .foregroundStyle(colors.accentDanger)
                    }

                    Text("Bio")
                        .font(PirateTokens.Typography.label)
                        .foregroundStyle(colors.textPrimary)
                    TextEditor(text: Binding(
                        get: { bio },
                        set: {
                            bio = String($0.prefix(settingsBioMax))
                            clearStatusMessages()
                        }
                    ))
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(8)
                    .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
                    Text("\(bio.count)/\(settingsBioMax)")
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.textSecondary)

                    saveButton(label: "Save profile", isEnabled: profileHasChanges) {
                        await saveProfile()
                    }
                }
            }

            settingsSection("Pirate handle") {
                pirateHandleSection
            }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        let profile = sessionManager.profile
        let label = displayName.nilIfEmpty ?? profileDisplayHandle(profile) ?? "Profile"
        let seed = profile?.userId.nilIfEmpty ?? profileDisplayHandle(profile) ?? label

        if let pendingAvatar {
            Image(uiImage: pendingAvatar.image)
                .resizable()
                .scaledToFill()
        } else {
            AvatarView(
                avatarRef: avatarRemoved ? nil : profile?.avatarRef,
                size: 112,
                fallbackLabel: label,
                fallbackSeed: seed
            )
        }
    }

    @ViewBuilder
    private var coverPreview: some View {
        let profile = sessionManager.profile
        let label = displayName.nilIfEmpty ?? profileDisplayHandle(profile) ?? "Profile"
        let seed = profile?.userId.nilIfEmpty ?? profileDisplayHandle(profile) ?? label

        if let pendingCover {
            Image(uiImage: pendingCover.image)
                .resizable()
                .scaledToFill()
        } else if !coverRemoved, let coverURL = ApiClient.shared.publicMediaURL(from: profile?.coverRef), coverURL.scheme != "data" {
            AsyncImage(url: coverURL) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    SettingsDefaultCover(displayName: label, userId: seed)
                }
            }
        } else {
            SettingsDefaultCover(displayName: label, userId: seed)
        }
    }

    @ViewBuilder
    private var pirateHandleSection: some View {
        if handleExpanded {
            VStack(alignment: .leading, spacing: 12) {
                infoRow(title: "Current handle", value: currentHandleDisplay)
                field(
                    "New handle",
                    text: Binding(
                        get: { handleEditLabel },
                        set: {
                            handleLabel = $0
                            clearStatusMessages()
                        }
                    )
                )

                HStack(spacing: 12) {
                    Button {
                        Task { await renameHandle() }
                    } label: {
                        HStack {
                            if isRenamingHandle { ProgressView().tint(colors.textOnAccent) }
                            Text(isRenamingHandle ? "Renaming..." : "Rename handle")
                        }
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                    }
                    .buttonStyle(.plain)
                    .disabled(isRenamingHandle)

                    Button {
                        handleExpanded = false
                        handleLabel = currentHandleDisplay
                    } label: {
                        settingsOutlineButtonLabel("Cancel")
                    }
                    .buttonStyle(.plain)
                    .disabled(isRenamingHandle)
                }
            }
        } else {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current handle")
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.textSecondary)
                    Text(currentHandleDisplay.isEmpty ? "No handle yet" : currentHandleDisplay)
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 12)
                Button {
                    handleExpanded = true
                    handleLabel = currentHandleDisplay
                    clearStatusMessages()
                } label: {
                    Text("Change")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.full))
                        .overlay(RoundedRectangle(cornerRadius: radii.full).stroke(colors.borderDefault, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.lg))
            .overlay(RoundedRectangle(cornerRadius: radii.lg).stroke(colors.borderSoft, lineWidth: 1))
        }
    }

    private enum ProfileMediaTarget {
        case avatar
        case cover

        var uploadKind: String {
            switch self {
            case .avatar: return "avatar"
            case .cover: return "cover"
            }
        }
    }

    private enum SettingsMediaShape {
        case avatar
        case cover
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(PirateTokens.Typography.h3)
                .foregroundStyle(colors.textPrimary)
            content()
        }
    }

    private func mediaControl<Preview: View>(
        title: String,
        hint: String? = nil,
        shape: SettingsMediaShape,
        selectedLabel: String?,
        canRemove: Bool,
        selectLabel: String,
        removeLabel: String,
        pickerSelection: Binding<PhotosPickerItem?>,
        onRemove: @escaping () -> Void,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PirateTokens.Typography.label)
                    .foregroundStyle(colors.textPrimary)
                if let hint {
                    Text(hint)
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.textSecondary)
                }
                if let selectedLabel {
                    Text(selectedLabel)
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            if shape == .avatar {
                preview()
                    .frame(width: 112, height: 112)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(colors.borderSoft, lineWidth: 1))
                    .background(colors.bgElevated)
            } else {
                preview()
                    .frame(height: 144)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: radii.xl))
                    .overlay(RoundedRectangle(cornerRadius: radii.xl).stroke(colors.borderSoft, lineWidth: 1))
                    .background(colors.bgElevated)
            }

            HStack(spacing: 12) {
                PhotosPicker(selection: pickerSelection, matching: .images) {
                    settingsOutlineButtonLabel(selectLabel)
                }
                .buttonStyle(.plain)
                .disabled(isSaving)

                if canRemove {
                    Button(action: onRemove) {
                        settingsOutlineButtonLabel(removeLabel)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
            }
        }
    }

    private func settingsOutlineButtonLabel(_ text: String) -> some View {
        Text(text)
            .font(PirateTokens.Typography.bodyStrong)
            .foregroundStyle(colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.full))
            .overlay(RoundedRectangle(cornerRadius: radii.full).stroke(colors.borderDefault, lineWidth: 1))
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferences")
                .font(PirateTokens.Typography.h3)
                .foregroundStyle(colors.textPrimary)
            field("Preferred locale", text: $preferredLocale)
            saveButton(label: "Save preferences") {
                await save(["preferred_locale": preferredLocale])
            }
        }
    }

    private var domainsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Domains")
                .font(PirateTokens.Typography.h3)
                .foregroundStyle(colors.textPrimary)
            if let handle = sessionManager.profile?.globalHandle?.label {
                infoRow(title: "Global handle", value: "@\(handle)")
            }
            let handles = sessionManager.profile?.linkedHandles ?? []
            if handles.isEmpty {
                Text("No linked domains yet.")
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)
            } else {
                ForEach(handles) { handle in
                    infoRow(title: handle.label, value: handle.verificationState ?? "linked")
                }
            }
        }
    }

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agents")
                .font(PirateTokens.Typography.h3)
                .foregroundStyle(colors.textPrimary)
            Text("Owned agent management is available on web. This native section is routed so agent surfaces can be added without another navigation pass.")
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textSecondary)
        }
    }

    private func field(_ title: String, text: Binding<String>, counter: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(PirateTokens.Typography.label)
                .foregroundStyle(colors.textPrimary)
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)
                .padding(12)
                .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
            if let counter {
                Text(counter)
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)
            }
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)
            Spacer()
            Text(value)
                .font(PirateTokens.Typography.caption)
                .foregroundStyle(colors.textSecondary)
        }
        .padding(12)
        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.md))
    }

    private func saveButton(label: String, isEnabled: Bool = true, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            HStack {
                if isSaving { ProgressView().tint(colors.textOnAccent) }
                Text(isSaving ? "Saving..." : label)
            }
            .font(PirateTokens.Typography.bodyStrong)
            .foregroundStyle(colors.textOnAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
        }
        .buttonStyle(.plain)
        .disabled(isSaving || !isEnabled)
        .opacity(isSaving || !isEnabled ? 0.6 : 1)
    }

    private var profileHasChanges: Bool {
        guard let profile = sessionManager.profile else { return false }
        return displayName.trimmingCharacters(in: .whitespacesAndNewlines) != (profile.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            || bio != (profile.bio ?? "")
            || pendingAvatar != nil
            || pendingCover != nil
            || (avatarRemoved && profile.avatarRef?.nilIfEmpty != nil)
            || (coverRemoved && profile.coverRef?.nilIfEmpty != nil)
    }

    private var currentHandleDisplay: String {
        profileDisplayHandle(sessionManager.profile) ?? ""
    }

    private var handleEditLabel: String {
        if handleLabel.lowercased().hasSuffix(".pirate") {
            return String(handleLabel.dropLast(".pirate".count))
        }
        return handleLabel
    }

    private func syncLocalStateFromProfile() {
        displayName = sessionManager.profile?.displayName ?? ""
        bio = sessionManager.profile?.bio ?? ""
        handleLabel = currentHandleDisplay
        preferredLocale = sessionManager.profile?.preferredLocale ?? ""
        pendingAvatar = nil
        pendingCover = nil
        avatarRemoved = false
        coverRemoved = false
        displayNameError = nil
        handleExpanded = false
        message = nil
        errorMessage = nil
    }

    private func clearStatusMessages() {
        message = nil
        errorMessage = nil
    }

    private func removeAvatar() {
        pendingAvatar = nil
        avatarRemoved = true
        avatarPickerItem = nil
        clearStatusMessages()
    }

    private func removeCover() {
        pendingCover = nil
        coverRemoved = true
        coverPickerItem = nil
        clearStatusMessages()
    }

    private func loadPickedMedia(_ item: PhotosPickerItem?, target: ProfileMediaTarget) async {
        guard let item else { return }

        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                await MainActor.run {
                    errorMessage = "Could not read that image."
                }
                return
            }

            let contentType = item.supportedContentTypes.first { $0.conforms(to: .image) } ?? .jpeg
            let mimeType = contentType.preferredMIMEType ?? "image/jpeg"
            let fileExtension = contentType.preferredFilenameExtension ?? "jpg"
            let selection = ProfileMediaSelection(
                data: data,
                filename: "\(target.uploadKind)-\(UUID().uuidString).\(fileExtension)",
                mimeType: mimeType,
                image: image
            )

            await MainActor.run {
                switch target {
                case .avatar:
                    pendingAvatar = selection
                    avatarRemoved = false
                case .cover:
                    pendingCover = selection
                    coverRemoved = false
                }
                clearStatusMessages()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Could not load that image."
            }
        }
    }

    private func renameHandle() async {
        var desiredLabel = handleLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if desiredLabel.lowercased().hasSuffix(".pirate") {
            desiredLabel.removeLast(".pirate".count)
        }
        desiredLabel = desiredLabel.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !desiredLabel.isEmpty else {
            errorMessage = "Handle is required."
            return
        }

        isRenamingHandle = true
        message = nil
        errorMessage = nil

        do {
            let result = try await ApiClient.shared.renameGlobalHandle(desiredLabel: desiredLabel)
            await sessionManager.refreshProfile()
            handleLabel = result.label
            handleExpanded = false
            message = "Handle updated to \(result.label)."
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }

        isRenamingHandle = false
    }

    private func saveProfile() async {
        guard let profile = sessionManager.profile else { return }
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDisplayName.isEmpty else {
            displayNameError = "Display name is required."
            return
        }
        guard profileHasChanges else { return }

        isSaving = true
        message = nil
        errorMessage = nil

        do {
            let avatarRef: String?
            if let pendingAvatar {
                avatarRef = try await ApiClient.shared.uploadProfileMedia(
                    kind: "avatar",
                    data: pendingAvatar.data,
                    filename: pendingAvatar.filename,
                    mimeType: pendingAvatar.mimeType
                ).mediaRef
            } else {
                avatarRef = nil
            }

            let coverRef: String?
            if let pendingCover {
                coverRef = try await ApiClient.shared.uploadProfileMedia(
                    kind: "cover",
                    data: pendingCover.data,
                    filename: pendingCover.filename,
                    mimeType: pendingCover.mimeType
                ).mediaRef
            } else {
                coverRef = nil
            }

            let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try await ApiClient.shared.updateProfile(ProfileUpdateInput(
                displayName: trimmedDisplayName,
                avatarRef: avatarRef,
                avatarSource: avatarRemoved ? "none" : nil,
                coverRef: coverRef,
                coverSource: coverRemoved ? "none" : nil,
                bio: trimmedBio.isEmpty ? nil : trimmedBio,
                clearBio: trimmedBio.isEmpty,
                bioSource: bio != (profile.bio ?? "") ? "manual" : nil
            ))
            await sessionManager.refreshProfile()
            pendingAvatar = nil
            pendingCover = nil
            avatarPickerItem = nil
            coverPickerItem = nil
            avatarRemoved = false
            coverRemoved = false
            message = "Profile updated."
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    private func save(_ updates: [String: String]) async {
        isSaving = true
        message = nil
        errorMessage = nil
        do {
            _ = try await ApiClient.shared.updateProfile(updates)
            await sessionManager.refreshProfile()
            message = "Saved."
        } catch let error as ApiError {
            errorMessage = error.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private var sectionTitle: String {
        switch section {
        case "profile": return "Profile Settings"
        case "preferences": return "Preferences"
        case "domains": return "Domains"
        case "agents": return "Agents"
        default: return section.capitalized
        }
    }
}
