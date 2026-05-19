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
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                        dismiss()
                    } label: {
                        PirateIconView(icon: .x, size: 18, color: colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(colors.bgElevated, in: Circle())
                            .overlay(Circle().stroke(colors.borderSoft, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }

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
            .padding(.vertical, 16)
        }
        .background(colors.bgPage)
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
                authButtonLabel(provider: .google, text: "Continue with Google")
            }

            Button {
                Task { await authService.loginWithTwitter() }
            } label: {
                authButtonLabel(provider: .twitter, text: "Continue with Twitter")
            }
        }
    }

    private func authButtonLabel(provider: SignInProviderIcon, text: String) -> some View {
        HStack(spacing: 10) {
            provider.icon
            Text(text)
                .font(PirateTokens.Typography.bodyStrong)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .foregroundStyle(colors.textPrimary)
        .background(colors.bgElevated, in: RoundedRectangle(cornerRadius: PirateTokens.radii.full))
        .overlay(
            RoundedRectangle(cornerRadius: PirateTokens.radii.full)
                .stroke(colors.borderDefault, lineWidth: 1)
        )
    }

    private var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#
        return trimmed.range(of: pattern, options: .regularExpression) != nil
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
                    emailActionLabel("Verify and Sign In", enabled: emailCode.count >= 6)
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
                            try await authService.sendEmailCode(email.trimmingCharacters(in: .whitespacesAndNewlines))
                            showEmailCode = true
                        } catch {
                            authService.authState = .error(error.localizedDescription)
                        }
                    }
                } label: {
                    emailActionLabel("Send Code", enabled: isEmailValid)
                }
                .disabled(!isEmailValid)
            }
        }
        .padding(.top, 8)
    }

    private func emailActionLabel(_ title: String, enabled: Bool) -> some View {
        Text(title)
            .font(PirateTokens.Typography.bodyStrong)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(enabled ? colors.textOnAccent : colors.textDisabled)
            .background(enabled ? colors.accentBrand : colors.bgElevated, in: RoundedRectangle(cornerRadius: PirateTokens.radii.full))
            .overlay(
                RoundedRectangle(cornerRadius: PirateTokens.radii.full)
                    .stroke(enabled ? colors.accentBrand : colors.borderSoft, lineWidth: 1)
            )
    }
}

private enum SignInProviderIcon {
    case google
    case twitter

    @ViewBuilder
    var icon: some View {
        switch self {
        case .google:
            PhosphorGoogleLogo()
                .stroke(Color(red: 0xEA / 255.0, green: 0x43 / 255.0, blue: 0x35 / 255.0), style: StrokeStyle(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                .frame(width: 26, height: 26)
        case .twitter:
            PhosphorTwitterLogo()
                .fill(Color(red: 0x1D / 255.0, green: 0x9B / 255.0, blue: 0xF0 / 255.0))
                .frame(width: 26, height: 26)
        }
    }
}

private struct PhosphorGoogleLogo: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scaleX = rect.width / 24
        let scaleY = rect.height / 24

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }

        path.move(to: point(21, 11.2))
        path.addLine(to: point(12.3, 11.2))
        path.move(to: point(20.5, 14.4))
        path.addCurve(to: point(12, 21), control1: point(19.4, 18.4), control2: point(16, 21))
        path.addCurve(to: point(3, 12), control1: point(7, 21), control2: point(3, 17))
        path.addCurve(to: point(12, 3), control1: point(3, 7), control2: point(7, 3))
        path.addCurve(to: point(18.4, 5.6), control1: point(14.5, 3), control2: point(16.8, 4))
        return path
    }
}

private struct PhosphorTwitterLogo: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scaleX = rect.width / 24
        let scaleY = rect.height / 24

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * scaleX, y: rect.minY + y * scaleY)
        }

        path.move(to: point(22, 5.9))
        path.addCurve(to: point(19.4, 6.6), control1: point(21.2, 6.3), control2: point(20.3, 6.5))
        path.addCurve(to: point(21.2, 4.3), control1: point(20.4, 6), control2: point(20.9, 5.2))
        path.addCurve(to: point(18.5, 5.3), control1: point(20.3, 4.8), control2: point(19.4, 5.1))
        path.addCurve(to: point(15.3, 4), control1: point(17.7, 4.5), control2: point(16.6, 4))
        path.addCurve(to: point(11.2, 8.1), control1: point(13, 4), control2: point(11.2, 5.8))
        path.addLine(to: point(11.2, 9))
        path.addCurve(to: point(4.2, 5.4), control1: point(7.9, 8.8), control2: point(5, 7.3))
        path.addCurve(to: point(3.7, 7.5), control1: point(3.8, 6.1), control2: point(3.7, 6.8))
        path.addCurve(to: point(5.5, 10.9), control1: point(3.7, 8.9), control2: point(4.4, 10.1))
        path.addCurve(to: point(3.7, 10.4), control1: point(4.9, 10.9), control2: point(4.3, 10.7))
        path.addCurve(to: point(7, 14.4), control1: point(4.2, 12.3), control2: point(5.4, 13.7))
        path.addCurve(to: point(5.1, 14.5), control1: point(6.4, 14.6), control2: point(5.7, 14.6))
        path.addCurve(to: point(9, 17.4), control1: point(5.9, 16.1), control2: point(7.3, 17.1))
        path.addCurve(to: point(3, 19.1), control1: point(7.3, 18.7), control2: point(5.2, 19.4))
        path.addCurve(to: point(12.9, 22), control1: point(5.1, 20.4), control2: point(7.7, 21.1))
        path.addCurve(to: point(20.8, 9.4), control1: point(18.8, 22), control2: point(20.8, 16.8))
        path.addLine(to: point(20.8, 8.8))
        path.addCurve(to: point(22, 5.9), control1: point(21.6, 8.2), control2: point(21.9, 7))
        path.closeSubpath()
        return path
    }
}
