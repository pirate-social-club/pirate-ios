import SwiftUI
import UniformTypeIdentifiers

struct CreateCommunityView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii
    @Environment(\.navigatePirateRoute) private var navigatePirateRoute
    var sessionManager: SessionManager

    @State private var step: CreateCommunityStep = .basics
    @State private var displayName = ""
    @State private var description = ""
    @State private var databaseRegion: CreateCommunityDatabaseRegion = .usEast
    @State private var membershipMode: CreateCommunityMembershipMode = .gated
    @State private var gateMatchMode: CreateCommunityGateMatchMode = .all
    @State private var selectedGateTypes: Set<CreateCommunityGateType> = [.altchaPow]
    @State private var nationalityCodesText = ""
    @State private var minimumAge = 30
    @State private var genderMarker: CreateCommunityGenderMarker = .female
    @State private var walletScore = 20
    @State private var erc721ContractAddress = ""
    @State private var ageGatePolicy: CreateCommunityAgeGatePolicy = .none
    @State private var allowAnonymousIdentity = true
    @State private var anonymousScope: CreateCommunityAnonymousScope = .communityStable
    @State private var avatarFile: ComposerPickedFile?
    @State private var bannerFile: ComposerPickedFile?
    @State private var showingMediaImporter = false
    @State private var mediaImportTarget: CreateCommunityMediaTarget?
    @State private var showSelfVerification = false
    @State private var pendingCreateAfterVerification = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var created: CommunityCreateAcceptedResponse?

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let created {
                        createdContent(created)
                    } else {
                        stepContent

                        if let errorMessage {
                            Text(errorMessage)
                                .font(PirateTokens.Typography.caption)
                                .foregroundStyle(colors.accentDanger)
                        }

                        footerActions
                    }
                }
                .padding(PirateTokens.pageGutter)
            }
            .background(colors.bgPage)
            .navigationTitle("Create community")
            .pirateNavigationChrome(colors: colors)
        }
        .task {
            await sessionManager.refreshUser()
        }
        .sheet(isPresented: $showSelfVerification) {
            SelfVerificationDrawer(
                sessionManager: sessionManager,
                intent: "community_creation",
                requestedCapabilities: ["age_over_18"],
                isPresented: $showSelfVerification,
                onVerified: {
                    await handleAgeVerificationComplete()
                }
            )
        }
        .fileImporter(
            isPresented: $showingMediaImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false,
            onCompletion: handleMediaImport
        )
    }

    private var trimmedDisplayName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var creatorAgeOver18Verified: Bool {
        sessionManager.user?.verificationCapabilities?.ageOver18?.state == "verified"
    }

    private var hasAdultMinimumAgeGate: Bool {
        membershipMode == .gated
            && selectedGateTypes.contains(.minimumAge)
            && minimumAge >= 18
            && minimumAge <= 125
    }

    private var effectiveDefaultAgeGatePolicy: CreateCommunityAgeGatePolicy {
        hasAdultMinimumAgeGate ? .eighteenPlus : ageGatePolicy
    }

    private var creatorAgeVerificationRequired: Bool {
        effectiveDefaultAgeGatePolicy == .eighteenPlus && !creatorAgeOver18Verified
    }

    private var parsedNationalityCodes: [String] {
        nationalityCodesText
            .split { character in
                character == "," || character == " " || character == "\n" || character == "\t"
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
    }

    private var nationalityCodesValid: Bool {
        parsedNationalityCodes.allSatisfy { code in
            code.range(of: "^[A-Z]{2}$", options: .regularExpression) != nil
        }
    }

    private var erc721ContractValid: Bool {
        let trimmed = erc721ContractAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: "^0x[0-9a-fA-F]{40}$", options: .regularExpression) != nil
    }

    private var gateDraftsValid: Bool {
        guard membershipMode == .gated else { return true }
        guard !selectedGateTypes.isEmpty else { return false }
        if selectedGateTypes.contains(.minimumAge), minimumAge < 18 || minimumAge > 125 {
            return false
        }
        if selectedGateTypes.contains(.walletScore), walletScore < 0 || walletScore > 100 {
            return false
        }
        if selectedGateTypes.contains(.erc721Holding), !erc721ContractValid {
            return false
        }
        if selectedGateTypes.contains(.nationality), !nationalityCodesValid {
            return false
        }
        return true
    }

    private var canCreateCommunity: Bool {
        !trimmedDisplayName.isEmpty && gateDraftsValid && !isSubmitting
    }

    private var canContinue: Bool {
        switch step {
        case .basics:
            return !trimmedDisplayName.isEmpty
        case .access:
            return gateDraftsValid
        case .review:
            return canCreateCommunity
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .basics:
            basicsStep
        case .access:
            accessStep
        case .review:
            reviewStep
        }
    }

    private var basicsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            PirateCard {
                VStack(alignment: .leading, spacing: 14) {
                    formLabel("Display name")
                    TextField("Community name", text: $displayName)
                        .textFieldStyle(.plain)
                        .font(PirateTokens.Typography.body)
                        .foregroundStyle(colors.textPrimary)
                        .padding(12)
                        .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))

                    formLabel("Description")
                    TextEditor(text: $description)
                        .font(PirateTokens.Typography.body)
                        .foregroundStyle(colors.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))

                    formLabel("Data region")
                    Picker("Data region", selection: $databaseRegion) {
                        ForEach(CreateCommunityDatabaseRegion.allCases) { region in
                            Text(region.label).tag(region)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(colors.accentBrand)
                }
            }

            PirateCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Images")
                        .font(PirateTokens.Typography.h3)
                        .foregroundStyle(colors.textPrimary)
                    mediaControl(title: "Avatar", file: avatarFile, target: .avatar)
                    mediaControl(title: "Banner", file: bannerFile, target: .banner)
                }
            }
        }
    }

    private var accessStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            PirateCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Join policy")
                        .font(PirateTokens.Typography.h3)
                        .foregroundStyle(colors.textPrimary)
                    ForEach(CreateCommunityMembershipMode.allCases) { mode in
                        optionButton(
                            title: mode.label,
                            detail: mode.detail,
                            selected: mode == membershipMode
                        ) {
                            setMembershipMode(mode)
                        }
                    }
                }
            }

            if membershipMode == .gated {
                PirateCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gate logic")
                            .font(PirateTokens.Typography.h3)
                            .foregroundStyle(colors.textPrimary)
                        ForEach(CreateCommunityGateMatchMode.allCases) { mode in
                            optionButton(
                                title: mode.label,
                                detail: mode.detail,
                                selected: mode == gateMatchMode
                            ) {
                                gateMatchMode = mode
                            }
                        }
                    }
                }

                PirateCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Identity gates")
                            .font(PirateTokens.Typography.h3)
                            .foregroundStyle(colors.textPrimary)
                        gateToggle(.altchaPow)
                        gateToggle(.uniqueHuman)
                        gateToggle(.nationality)
                        if selectedGateTypes.contains(.nationality) {
                            VStack(alignment: .leading, spacing: 6) {
                                formLabel("Allowed nationalities")
                                TextField("US, CA", text: $nationalityCodesText)
                                    .textFieldStyle(.plain)
                                    .font(PirateTokens.Typography.body)
                                    .foregroundStyle(colors.textPrimary)
                                    .padding(12)
                                    .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
                                if !nationalityCodesValid {
                                    warningText("Select a valid country.")
                                }
                            }
                        }

                        gateToggle(.minimumAge)
                        if selectedGateTypes.contains(.minimumAge) {
                            Stepper(value: $minimumAge, in: 18...125) {
                                Text("Minimum age \(minimumAge)")
                                    .font(PirateTokens.Typography.body)
                                    .foregroundStyle(colors.textPrimary)
                            }
                            .padding(.leading, 4)
                        }

                        gateToggle(.gender)
                        if selectedGateTypes.contains(.gender) {
                            Picker("Document sex marker", selection: $genderMarker) {
                                ForEach(CreateCommunityGenderMarker.allCases) { marker in
                                    Text(marker.label).tag(marker)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                PirateCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Wallet gates")
                            .font(PirateTokens.Typography.h3)
                            .foregroundStyle(colors.textPrimary)
                        gateToggle(.walletScore)
                        if selectedGateTypes.contains(.walletScore) {
                            Stepper(value: $walletScore, in: 0...100) {
                                Text("Minimum score \(walletScore)")
                                    .font(PirateTokens.Typography.body)
                                    .foregroundStyle(colors.textPrimary)
                            }
                            .padding(.leading, 4)
                        }

                        gateToggle(.erc721Holding)
                        if selectedGateTypes.contains(.erc721Holding) {
                            VStack(alignment: .leading, spacing: 6) {
                                formLabel("Collection contract")
                                TextField("0x...", text: $erc721ContractAddress)
                                    .textFieldStyle(.plain)
                                    .font(PirateTokens.Typography.body)
                                    .foregroundStyle(colors.textPrimary)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .padding(12)
                                    .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
                                if !erc721ContractAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !erc721ContractValid {
                                    warningText("Enter a valid Ethereum contract address.")
                                }
                            }
                        }

                        disabledGateRow("Courtyard.io collectibles (Coming soon)")
                    }
                }
            }

            if !hasAdultMinimumAgeGate {
                PirateCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Age restriction")
                            .font(PirateTokens.Typography.h3)
                            .foregroundStyle(colors.textPrimary)
                        Toggle(isOn: Binding(
                            get: { ageGatePolicy == .eighteenPlus },
                            set: { checked in ageGatePolicy = checked ? .eighteenPlus : .none }
                        )) {
                            Text("18+ community")
                                .font(PirateTokens.Typography.bodyStrong)
                                .foregroundStyle(colors.textPrimary)
                        }
                        .tint(colors.accentBrand)

                        if ageGatePolicy == .eighteenPlus && !creatorAgeOver18Verified {
                            warningText("The owner must complete age verification before marking a community for adult content.")
                        }
                    }
                }
            }

            PirateCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Identity and access")
                        .font(PirateTokens.Typography.h3)
                        .foregroundStyle(colors.textPrimary)
                    Toggle(isOn: $allowAnonymousIdentity) {
                        Text("Allow anonymous posting")
                            .font(PirateTokens.Typography.bodyStrong)
                            .foregroundStyle(colors.textPrimary)
                    }
                    .tint(colors.accentBrand)

                    if allowAnonymousIdentity {
                        VStack(alignment: .leading, spacing: 10) {
                            formLabel("Anonymous scope")
                            ForEach(CreateCommunityAnonymousScope.allCases) { scope in
                                optionButton(
                                    title: scope.label,
                                    detail: scope.detail,
                                    selected: scope == anonymousScope
                                ) {
                                    anonymousScope = scope
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var reviewStep: some View {
        PirateCard {
            VStack(alignment: .leading, spacing: 14) {
                reviewRow("Name", trimmedDisplayName)
                reviewRow("Description", trimmedDescription.isEmpty ? "None" : trimmedDescription)
                reviewRow("Data region", databaseRegion.label)
                reviewRow("Membership", membershipMode.reviewLabel)
                reviewRow("Content rating", effectiveDefaultAgeGatePolicy.label)
                if let gateRequirementSummary {
                    reviewRow("Membership gates", gateRequirementSummary)
                }
                reviewRow("Anonymous posting", allowAnonymousIdentity ? "Enabled" : "Disabled")
                if allowAnonymousIdentity {
                    reviewRow("Anonymous scope", anonymousScope.label)
                }
                if let avatarFile {
                    reviewRow("Avatar", avatarFile.name)
                }
                if let bannerFile {
                    reviewRow("Banner", bannerFile.name)
                }
                if creatorAgeVerificationRequired {
                    warningText("This community is marked 18+, so the creator must also pass age verification before launch.")
                }
            }
        }
    }

    private var footerActions: some View {
        HStack(spacing: 12) {
            if let previous = step.previous {
                Button {
                    step = previous
                } label: {
                    Text("Back")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.accentBrand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.full))
                }
                .buttonStyle(.plain)
            }

            if let next = step.next {
                Button {
                    if canContinue {
                        step = next
                    }
                } label: {
                    Text("Continue")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                }
                .buttonStyle(.plain)
                .disabled(!canContinue)
                .opacity(canContinue ? 1 : 0.55)
            } else {
                Button {
                    beginCreateCommunity()
                } label: {
                    HStack {
                        if isSubmitting { ProgressView().tint(colors.textOnAccent) }
                        Text(isSubmitting ? "Creating..." : "Create community")
                    }
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                }
                .buttonStyle(.plain)
                .disabled(!canCreateCommunity)
                .opacity(canCreateCommunity ? 1 : 0.55)
            }
        }
    }

    private func createdContent(_ created: CommunityCreateAcceptedResponse) -> some View {
        PirateCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Community created")
                    .font(PirateTokens.Typography.h3)
                    .foregroundStyle(colors.textPrimary)
                Text("Provisioning: \(created.job?.status ?? "accepted")")
                    .font(PirateTokens.Typography.caption)
                    .foregroundStyle(colors.textSecondary)
                NavigationLink(value: PirateRoute.communityModerationSection(created.community.id, "namespace")) {
                    Text("Continue to namespace")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.full))
                }
                .buttonStyle(.plain)
                NavigationLink(value: PirateRoute.community(created.community.id)) {
                    Text("Open community")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.accentBrand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.full))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func formLabel(_ value: String) -> some View {
        Text(value)
            .font(PirateTokens.Typography.bodyStrong)
            .foregroundStyle(colors.textPrimary)
    }

    private func warningText(_ value: String) -> some View {
        Text(value)
            .font(PirateTokens.Typography.caption)
            .foregroundStyle(colors.accentDanger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(colors.surfaceSubtle, in: RoundedRectangle(cornerRadius: radii.md))
    }

    private func optionButton(
        title: String,
        detail: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(selected ? colors.accentBrand : colors.borderDefault)
                    .frame(width: 12, height: 12)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textPrimary)
                    Text(detail)
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(selected ? colors.surfaceSubtle : colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
            .overlay(
                RoundedRectangle(cornerRadius: radii.md)
                    .stroke(selected ? colors.borderDefault : colors.borderSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func gateToggle(_ type: CreateCommunityGateType) -> some View {
        Toggle(isOn: Binding(
            get: { selectedGateTypes.contains(type) },
            set: { checked in setGate(type, enabled: checked) }
        )) {
            Text(type.title)
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(colors.textPrimary)
        }
        .tint(colors.accentBrand)
        .padding(12)
        .background(selectedGateTypes.contains(type) ? colors.surfaceSubtle : colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
        .overlay(
            RoundedRectangle(cornerRadius: radii.md)
                .stroke(selectedGateTypes.contains(type) ? colors.borderDefault : colors.borderSoft, lineWidth: 1)
        )
    }

    private func disabledGateRow(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(colors.textSecondary)
            Spacer()
        }
        .padding(12)
        .background(colors.bgSurface, in: RoundedRectangle(cornerRadius: radii.md))
        .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))
        .opacity(0.6)
    }

    private func mediaControl(title: String, file: ComposerPickedFile?, target: CreateCommunityMediaTarget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            formLabel(title)
            HStack(spacing: 12) {
                mediaPreview(file: file, target: target)
                VStack(alignment: .leading, spacing: 6) {
                    Text(file?.name ?? "No file selected")
                        .font(PirateTokens.Typography.bodyStrong)
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("PNG, JPG, WebP")
                        .font(PirateTokens.Typography.caption)
                        .foregroundStyle(colors.textSecondary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 12) {
                Button {
                    mediaImportTarget = target
                    showingMediaImporter = true
                } label: {
                    outlineButtonLabel(file == nil ? "Choose file" : "Replace")
                }
                .buttonStyle(.plain)

                if file != nil {
                    Button {
                        switch target {
                        case .avatar: avatarFile = nil
                        case .banner: bannerFile = nil
                        }
                    } label: {
                        outlineButtonLabel("Remove")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func mediaPreview(file: ComposerPickedFile?, target: CreateCommunityMediaTarget) -> some View {
        ZStack {
            if let file, let image = makeImage(from: file.data) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(colors.bgElevated)
                    .overlay(PirateIconView(icon: .image, filled: true, size: 24, color: colors.textSecondary))
            }
        }
        .frame(width: target == .avatar ? 64 : 96, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: target == .avatar ? radii.full : radii.md))
        .overlay(RoundedRectangle(cornerRadius: target == .avatar ? radii.full : radii.md).stroke(colors.borderSoft, lineWidth: 1))
    }

    private func outlineButtonLabel(_ text: String) -> some View {
        Text(text)
            .font(PirateTokens.Typography.bodyStrong)
            .foregroundStyle(colors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.full))
            .overlay(RoundedRectangle(cornerRadius: radii.full).stroke(colors.borderDefault, lineWidth: 1))
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(PirateTokens.Typography.smallStrong)
                .foregroundStyle(colors.textSecondary)
            Text(value)
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private var gateRequirementSummary: String? {
        guard membershipMode == .gated else { return nil }
        let values = CreateCommunityGateType.reviewOrder
            .filter { selectedGateTypes.contains($0) }
            .map(gateRequirementLabel)
        return values.isEmpty ? nil : values.joined(separator: ", ")
    }

    private func gateRequirementLabel(for type: CreateCommunityGateType) -> String {
        switch type {
        case .altchaPow:
            return "Proof-of-work check"
        case .uniqueHuman:
            return "Palm scan"
        case .nationality:
            let codes = parsedNationalityCodes
            return codes.isEmpty ? "Nationality verification" : "\(codes.joined(separator: ", ")) nationality"
        case .minimumAge:
            return "\(minimumAge)+ ID check"
        case .gender:
            return "Requires document sex marker \(genderMarker.rawValue)"
        case .walletScore:
            return "Passport Score \(walletScore)+"
        case .erc721Holding:
            let address = erc721ContractAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            return address.isEmpty ? "Ethereum NFT" : "Ethereum NFT from \(shortAddress(address))"
        }
    }

    private func shortAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    private func setMembershipMode(_ mode: CreateCommunityMembershipMode) {
        membershipMode = mode
        if mode == .request {
            selectedGateTypes = []
        } else if selectedGateTypes.isEmpty {
            selectedGateTypes = [.altchaPow]
        }
    }

    private func setGate(_ type: CreateCommunityGateType, enabled: Bool) {
        if enabled {
            if type == .altchaPow {
                selectedGateTypes.subtract(CreateCommunityGateType.powExclusiveTypes)
            } else if CreateCommunityGateType.powExclusiveTypes.contains(type) {
                selectedGateTypes.remove(.altchaPow)
            }
            selectedGateTypes.insert(type)
        } else {
            selectedGateTypes.remove(type)
        }
    }

    private func handleMediaImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first, let target = mediaImportTarget else { return }
            Task { await loadCommunityMedia(url: url, target: target) }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func loadCommunityMedia(url: URL, target: CreateCommunityMediaTarget) async {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/jpeg"
            let file = ComposerPickedFile(
                name: url.lastPathComponent,
                mimeType: mimeType,
                data: data,
                sizeBytes: data.count
            )
            switch target {
            case .avatar:
                avatarFile = file
            case .banner:
                bannerFile = file
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func beginCreateCommunity() {
        guard canCreateCommunity else { return }
        if creatorAgeVerificationRequired {
            pendingCreateAfterVerification = true
            errorMessage = nil
            showSelfVerification = true
            return
        }
        Task { await createCommunity() }
    }

    private func handleAgeVerificationComplete() async {
        await sessionManager.refreshUser()
        guard !creatorAgeVerificationRequired else {
            errorMessage = "Verify 18+ status before creating an 18+ community."
            pendingCreateAfterVerification = false
            return
        }

        showSelfVerification = false
        if pendingCreateAfterVerification {
            pendingCreateAfterVerification = false
            await createCommunity()
        }
    }

    private func createCommunity() async {
        guard canCreateCommunity else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            let avatarRef = try await uploadCommunityMediaIfNeeded(kind: "avatar", file: avatarFile)
            let bannerRef = try await uploadCommunityMediaIfNeeded(kind: "banner", file: bannerFile)
            let result = try await ApiClient.shared.createCommunity(CreateCommunityRequest(
                displayName: trimmedDisplayName,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                avatarRef: avatarRef,
                bannerRef: bannerRef,
                databaseRegion: databaseRegion.rawValue,
                membershipMode: membershipMode.rawValue,
                defaultAgeGatePolicy: effectiveDefaultAgeGatePolicy.rawValue,
                allowAnonymousIdentity: allowAnonymousIdentity,
                anonymousIdentityScope: anonymousScope.rawValue,
                gatePolicy: serializedGatePolicy,
                communityBootstrap: Self.defaultBootstrap
            ))
            created = result
            navigatePirateRoute(.community(result.community.id))
        } catch let error as ApiError {
            if error.displayMessage.contains("age_over_18") || error.diagnosticMessage.contains("age_over_18") {
                pendingCreateAfterVerification = true
                showSelfVerification = true
                errorMessage = "Age verification is required to create an 18+ community."
            } else {
                errorMessage = error.displayMessage
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func uploadCommunityMediaIfNeeded(kind: String, file: ComposerPickedFile?) async throws -> String? {
        guard let file else { return nil }
        return try await ApiClient.shared.uploadCommunityMedia(
            kind: kind,
            data: file.data,
            filename: file.name,
            mimeType: file.mimeType
        ).mediaRef
    }

    private var serializedGatePolicy: JSONValue? {
        guard membershipMode == .gated else { return nil }
        let expressions = CreateCommunityGateType.reviewOrder.compactMap { type -> JSONValue? in
            guard selectedGateTypes.contains(type) else { return nil }
            return gateExpression(for: type)
        }
        guard !expressions.isEmpty else { return nil }
        return .object([
            "version": .int(1),
            "expression": .object([
                "op": .string(gateMatchMode == .any ? "or" : "and"),
                "children": .array(expressions)
            ])
        ])
    }

    private func gateExpression(for type: CreateCommunityGateType) -> JSONValue? {
        if type == .uniqueHuman {
            return .object([
                "op": .string("or"),
                "children": .array([
                    .object([
                        "op": .string("gate"),
                        "gate": .object([
                            "type": .string("unique_human"),
                            "provider": .string("self")
                        ])
                    ]),
                    .object([
                        "op": .string("gate"),
                        "gate": .object([
                            "type": .string("unique_human"),
                            "provider": .string("very")
                        ])
                    ])
                ])
            ])
        }
        guard let atom = gateAtom(for: type) else { return nil }
        return .object([
            "op": .string("gate"),
            "gate": atom
        ])
    }

    private func gateAtom(for type: CreateCommunityGateType) -> JSONValue? {
        switch type {
        case .altchaPow:
            return .object(["type": .string("altcha_pow")])
        case .uniqueHuman:
            return nil
        case .nationality:
            return .object([
                "type": .string("nationality"),
                "provider": .string("self"),
                "allowed": .array(parsedNationalityCodes.map { .string($0) })
            ])
        case .minimumAge:
            return .object([
                "type": .string("minimum_age"),
                "provider": .string("self"),
                "minimum_age": .int(minimumAge)
            ])
        case .gender:
            return .object([
                "type": .string("gender"),
                "provider": .string("self"),
                "allowed": .array([.string(genderMarker.rawValue)])
            ])
        case .walletScore:
            return .object([
                "type": .string("wallet_score"),
                "provider": .string("passport"),
                "minimum_score": .int(walletScore)
            ])
        case .erc721Holding:
            return .object([
                "type": .string("erc721_holding"),
                "chain_namespace": .string("eip155:1"),
                "contract_address": .string(erc721ContractAddress.trimmingCharacters(in: .whitespacesAndNewlines))
            ])
        }
    }

    private static let defaultBootstrap = CreateCommunityBootstrapInput(rules: [
        CreateCommunityRuleInput(
            title: "Respect others and be civil",
            body: "No harassment, hate speech, or toxic behavior. Treat all contributors and members with kindness.",
            reportReason: "Respect others and be civil",
            position: 0
        ),
        CreateCommunityRuleInput(
            title: "No spam",
            body: "Excessive promotion, spam, or advertising of any kind is not allowed.",
            reportReason: "No spam",
            position: 1
        )
    ])
}
