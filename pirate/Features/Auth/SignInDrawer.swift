import SwiftUI

struct SignInDrawer: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @Bindable var sessionManager: SessionManager
    @Binding var isPresented: Bool

    @State private var authService = AuthService.shared
    @State private var email = ""
    @State private var emailCode = ""
    @State private var showEmailCode = false
    @State private var isExchangingSession = false
    @State private var didCompleteSessionExchange = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    if case .loading = authService.authState {
                        ProgressView()
                            .tint(colors.accentBrand)
                            .scaleEffect(1.2)
                    } else if isExchangingSession {
                        ProgressView()
                            .tint(colors.accentBrand)
                            .scaleEffect(1.2)
                    } else if case let .error(message) = authService.authState {
                        errorBanner(message)
                    }

                    authButtons

                    emailForm
                }
                .padding(.horizontal, PirateTokens.pageGutter)
                .padding(.vertical, 24)
            }
            .background(colors.bgPage)
            .navigationTitle("Sign In")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                    .foregroundStyle(colors.textSecondary)
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        .task {
            authService.initialize()
            await authService.refreshAuthState()
            await exchangeIfAuthenticated()
        }
        .onChange(of: authService.authState) { _, newState in
            if case .authenticated = newState {
                Task { await exchangeIfAuthenticated() }
            }
        }
    }

    private func exchangeIfAuthenticated() async {
        guard !didCompleteSessionExchange, !isExchangingSession else { return }
        guard case .authenticated = authService.authState else { return }
        guard let proof = await authService.sessionExchangeProof() else {
            authService.authState = .error("Privy did not return an access token.")
            return
        }

        isExchangingSession = true
        defer { isExchangingSession = false }

        do {
            let session = try await ApiClient.shared.exchangeSession(proof: proof)
            didCompleteSessionExchange = true
            sessionManager.setSession(session)
            isPresented = false
            dismiss()
        } catch let error as ApiError {
            authService.authState = .error(error.diagnosticMessage)
        } catch {
            authService.authState = .error(error.localizedDescription)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Welcome to Pirate")
                .font(PirateTokens.Typography.h2)
                .foregroundStyle(colors.textPrimary)
            Text("Sign in to join communities, post, and more.")
                .font(PirateTokens.Typography.caption)
                .foregroundStyle(colors.textSecondary)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(PirateTokens.Typography.small)
            .foregroundStyle(colors.accentDanger)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colors.surfaceDanger, in: RoundedRectangle(cornerRadius: PirateTokens.radii.md))
    }

    private var authButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await authService.loginWithGoogle() }
            } label: {
                authButtonLabel(icon: "globe", text: "Google", isPrimary: true)
            }

            Button {
                Task { await authService.loginWithTwitter() }
            } label: {
                authButtonLabel(icon: "xmark", text: "X", isPrimary: false)
            }
        }
    }

    private func authButtonLabel(icon: String, text: String, isPrimary: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
            Text(text)
                .font(PirateTokens.Typography.bodyStrong)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .foregroundStyle(isPrimary ? colors.textOnAccent : colors.textPrimary)
        .background(isPrimary ? colors.accentBrand : colors.bgElevated, in: RoundedRectangle(cornerRadius: PirateTokens.radii.full))
        .overlay(
            RoundedRectangle(cornerRadius: PirateTokens.radii.full)
                .stroke(isPrimary ? Color.clear : colors.borderDefault, lineWidth: isPrimary ? 0 : 1)
        )
    }

    private var emailForm: some View {
        VStack(spacing: 12) {
            if showEmailCode {
                TextField("Verification code", text: $emailCode)
                    .textFieldStyle(.plain)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textPrimary)
                    .padding(12)
                    .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: PirateTokens.radii.md))
                    .overlay(RoundedRectangle(cornerRadius: PirateTokens.radii.md).stroke(colors.borderDefault, lineWidth: 1))

                Button {
                    Task { await authService.loginWithEmailCode(emailCode, email: email) }
                } label: {
                    Text("Verify and Sign In")
                        .font(PirateTokens.Typography.bodyStrong)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(colors.textOnAccent)
                        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: PirateTokens.radii.full))
                }
                .disabled(emailCode.count < 6)
            } else {
                TextField("Email address", text: $email)
                    .textFieldStyle(.plain)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textPrimary)
                    .padding(12)
                    .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: PirateTokens.radii.md))
                    .overlay(RoundedRectangle(cornerRadius: PirateTokens.radii.md).stroke(colors.borderDefault, lineWidth: 1))
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    #endif

                Button {
                    Task {
                        do {
                            try await authService.sendEmailCode(email)
                            showEmailCode = true
                        } catch {
                            authService.authState = .error(error.localizedDescription)
                        }
                    }
                } label: {
                    Text("Send Code")
                        .font(PirateTokens.Typography.bodyStrong)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(colors.textOnAccent)
                        .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: PirateTokens.radii.full))
                }
                .disabled(email.isEmpty || !email.contains("@"))
            }
        }
        .padding(.top, 8)
    }
}
