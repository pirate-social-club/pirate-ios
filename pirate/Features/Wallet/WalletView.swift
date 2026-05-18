import CoreImage.CIFilterBuiltins
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

private enum WalletChainId: String, CaseIterable, Identifiable {
    case ethereum
    case base
    case optimism
    case story
    case tempo
    case bitcoin
    case solana
    case cosmos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ethereum: return "Ethereum"
        case .base: return "Base"
        case .optimism: return "Optimism"
        case .story: return "Story"
        case .tempo: return "Tempo"
        case .bitcoin: return "Bitcoin"
        case .solana: return "Solana"
        case .cosmos: return "Cosmos"
        }
    }

    var iconName: String? {
        switch self {
        case .ethereum: return "wallet_icon_ethereum"
        case .base: return "wallet_icon_base"
        case .optimism: return "wallet_icon_optimism"
        case .story: return "wallet_icon_story"
        case .tempo: return "wallet_icon_tempo"
        case .bitcoin: return nil
        case .solana: return "wallet_icon_solana"
        case .cosmos: return "wallet_icon_cosmos"
        }
    }
}

private enum WalletIconKind: Equatable {
    case asset(String)
    case bitcoin
    case fallback(String)
}

private struct WalletAssetRow: Identifiable {
    let id: String
    let symbol: String
    let name: String
    let chainId: WalletChainId
    let chainTitle: String
    let tokenIcon: WalletIconKind
    let chainIcon: WalletIconKind?
    let balance: String
    let fiatValue: String

    var showsChainBadge: Bool {
        chainId != .bitcoin
    }
}

private struct WalletChainSection: Identifiable {
    let chainId: WalletChainId
    let title: String
    let walletAddress: String?
    let assets: [WalletAssetRow]

    var id: WalletChainId { chainId }
}

struct WalletView: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii

    var sessionManager: SessionManager

    @State private var claimableRoyalties: WalletClaimableRoyaltiesResponse = .empty
    @State private var claimLoading = false
    @State private var showReceiveSheet = false
    @State private var receiveChainId: WalletChainId = .ethereum
    @State private var showClaimUnavailable = false

    private var primaryWalletAddress: String? {
        sessionManager.currentSession?.profile.primaryWalletAddress?.trimmedNonEmpty
            ?? sessionManager.primaryWalletAddress?.trimmedNonEmpty
    }

    private var chainSections: [WalletChainSection] {
        buildWalletChainSections(walletAddress: primaryWalletAddress)
    }

    private var assetRows: [WalletAssetRow] {
        chainSections.flatMap(\.assets).sorted(by: sortWalletAssetRows)
    }

    private var hasClaimableRoyalties: Bool {
        hasNonZeroWei(claimableRoyalties.totalClaimableWipWei)
    }

    var body: some View {
        AuthGate(isAuthenticated: sessionManager.isAuthenticated, sessionManager: sessionManager) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MobilePageHeader("Wallet")
                    balanceSection
                    royaltiesSection
                    assetsSection
                }
                .padding(.bottom, 24)
            }
            .background(colors.bgPage)
            .hiddenRootNavigationBar()
            .task(id: sessionManager.currentSession?.accessToken) {
                await refreshClaimableRoyalties()
            }
            .sheet(isPresented: $showReceiveSheet) {
                WalletReceiveSheet(
                    chainSections: chainSections,
                    selectedChainId: $receiveChainId,
                    walletAddress: primaryWalletAddress
                )
                .walletSheetPresentation()
            }
            .alert("Claim royalties", isPresented: $showClaimUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Royalty claiming is not wired up in the iOS app yet.")
            }
        }
    }

    private var balanceSection: some View {
        let walletAddress = primaryWalletAddress
        let showWalletActions = walletAddress != nil

        return VStack(alignment: .leading, spacing: 0) {
            Text("Total balance")
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textSecondary)
            Text("$0.00")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(colors.textPrimary)
                .monospacedDigit()
                .padding(.top, 2)
            if showWalletActions {
                HStack(spacing: 12) {
                    WalletOutlineButton(title: "Send", enabled: false) {}
                    WalletOutlineButton(title: "Receive", enabled: walletAddress != nil) {
                        receiveChainId = defaultReceiveChainId
                        showReceiveSheet = true
                    }
                }
                .padding(.top, 16)
            }
        }
        .padding(.horizontal, PirateTokens.pageGutter)
        .padding(.vertical, 16)
    }

    private var royaltiesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().overlay(colors.borderSoft)
            Text("Royalties")
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textSecondary)
                .padding(.top, 16)
            Text("$\(formatWipAmount(claimableRoyalties.totalClaimableWipWei))")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(colors.textPrimary)
                .monospacedDigit()
                .padding(.top, 2)
            WalletPrimaryButton(
                title: "Claim",
                enabled: hasClaimableRoyalties,
                loading: claimLoading
            ) {
                showClaimUnavailable = true
            }
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, PirateTokens.pageGutter)
    }

    private var assetsSection: some View {
        VStack(spacing: 0) {
            Divider().overlay(colors.borderSoft)
            if assetRows.isEmpty {
                Text("No assets yet.")
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
            } else {
                ForEach(assetRows.indices, id: \.self) { index in
                    WalletMobileAssetRow(asset: assetRows[index])
                    if index < assetRows.count - 1 {
                        Divider().overlay(colors.borderSoft)
                    }
                }
            }
            Divider().overlay(colors.borderSoft)
        }
        .background(colors.bgPage)
    }

    private var defaultReceiveChainId: WalletChainId {
        chainSections.first { $0.walletAddress?.trimmedNonEmpty != nil }?.chainId
            ?? chainSections.first?.chainId
            ?? .ethereum
    }

    private func refreshClaimableRoyalties() async {
        guard sessionManager.isAuthenticated else {
            claimableRoyalties = .empty
            claimLoading = false
            return
        }

        claimLoading = true
        defer { claimLoading = false }

        do {
            claimableRoyalties = try await ApiClient.shared.walletClaimableRoyalties()
        } catch {
            claimableRoyalties = .empty
        }
    }
}

private struct WalletClaimableRoyaltiesResponse: Decodable {
    let totalClaimableWipWei: String

    enum CodingKeys: String, CodingKey {
        case totalClaimableWipWei = "total_claimable_wip_wei"
    }

    static let empty = WalletClaimableRoyaltiesResponse(totalClaimableWipWei: "0")
}

private extension ApiClient {
    func walletClaimableRoyalties() async throws -> WalletClaimableRoyaltiesResponse {
        try await request(path: "/royalties/claimable")
    }
}

private struct WalletOutlineButton: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii

    let title: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(enabled ? colors.textPrimary : colors.textDisabled)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(colors.bgPage, in: RoundedRectangle(cornerRadius: radii.lg))
                .overlay(RoundedRectangle(cornerRadius: radii.lg).stroke(colors.borderSoft, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct WalletPrimaryButton: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii

    let title: String
    let enabled: Bool
    let loading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(PirateTokens.Typography.bodyStrong)
                    .opacity(loading ? 0 : 1)
                if loading {
                    ProgressView()
                        .tint(enabled ? colors.textOnAccent : colors.textDisabled)
                }
            }
            .foregroundStyle(enabled ? colors.textOnAccent : colors.textDisabled)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(enabled ? colors.accentBrand : colors.bgElevated, in: RoundedRectangle(cornerRadius: radii.lg))
            .overlay(RoundedRectangle(cornerRadius: radii.lg).stroke(enabled ? colors.accentBrand : colors.borderSoft, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled || loading)
    }
}

private struct WalletMobileAssetRow: View {
    @Environment(\.pirateColors) private var colors

    let asset: WalletAssetRow

    var body: some View {
        HStack(spacing: 12) {
            TokenChainMark(asset: asset)
            Text(asset.symbol)
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(asset.balance)
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textPrimary)
                    .monospacedDigit()
                Text(asset.fiatValue)
                    .font(PirateTokens.Typography.small)
                    .foregroundStyle(colors.textSecondary)
                    .monospacedDigit()
            }
            .frame(minWidth: 72, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(colors.bgPage)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(asset.symbol), \(asset.chainTitle), \(asset.balance), \(asset.fiatValue)")
    }
}

private struct TokenChainMark: View {
    let asset: WalletAssetRow

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            WalletIconCircle(kind: asset.tokenIcon, size: 40, iconSize: 28)
            if asset.showsChainBadge, let chainIcon = asset.chainIcon {
                WalletIconCircle(kind: chainIcon, size: 18, iconSize: 14, borderColor: .white.opacity(0.7), padding: 2)
                    .offset(x: 1, y: 1)
            }
        }
        .frame(width: 42, height: 42)
    }
}

private struct WalletIconCircle: View {
    @Environment(\.pirateColors) private var colors

    let kind: WalletIconKind
    let size: CGFloat
    let iconSize: CGFloat
    var borderColor: Color? = nil
    var padding: CGFloat = 6

    var body: some View {
        ZStack {
            Circle().fill(backgroundColor)
            icon
                .frame(width: iconSize, height: iconSize)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(borderColor ?? colors.borderSoft, lineWidth: 1))
    }

    private var backgroundColor: Color {
        switch kind {
        case .bitcoin:
            return Color(red: 0xF7 / 255.0, green: 0x93 / 255.0, blue: 0x1A / 255.0)
        case .asset:
            return .white
        case .fallback:
            return colors.bgElevated
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
                .padding(padding)
        case .bitcoin:
            Image(systemName: "bitcoinsign")
                .font(.system(size: iconSize * 0.74, weight: .bold))
                .foregroundStyle(.white)
        case .fallback(let label):
            Text(String(label.prefix(1)).uppercased())
                .font(.system(size: iconSize * 0.55, weight: .semibold))
                .foregroundStyle(colors.textPrimary)
        }
    }
}

private struct WalletReceiveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii

    let chainSections: [WalletChainSection]
    @Binding var selectedChainId: WalletChainId
    let walletAddress: String?

    private var selectedChain: WalletChainSection? {
        chainSections.first { $0.chainId == selectedChainId } ?? chainSections.first
    }

    private var selectedAddress: String? {
        selectedChain?.walletAddress?.trimmedNonEmpty ?? walletAddress?.trimmedNonEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(colors.textSecondary.opacity(0.6))
                .frame(width: 48, height: 6)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 18)

            Text("Receive")
                .font(PirateTokens.Typography.h2)
                .foregroundStyle(colors.textPrimary)
            Text("Choose the network before sharing your wallet address.")
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textSecondary)
                .padding(.top, 4)

            if let selectedChain, let selectedAddress {
                receiveContent(chain: selectedChain, address: selectedAddress)
            } else {
                noWalletContent
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(colors.bgPage.ignoresSafeArea())
    }

    private func receiveContent(chain: WalletChainSection, address: String) -> some View {
        VStack(spacing: 20) {
            HStack {
                Text("Network")
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textSecondary)
                Spacer()
                Menu {
                    ForEach(chainSections) { section in
                        Button {
                            selectedChainId = section.chainId
                        } label: {
                            Text(section.title)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        ChainIconMark(chainId: chain.chainId, size: 22, framed: false)
                        Text(chain.title)
                            .font(PirateTokens.Typography.bodyStrong)
                            .foregroundStyle(colors.textPrimary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(colors.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ChainIconMark(chainId: chain.chainId, size: 44, framed: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(chain.title)
                            .font(PirateTokens.Typography.bodyStrong)
                            .foregroundStyle(colors.textPrimary)
                        Text(address.shortWalletAddress)
                            .font(PirateTokens.Typography.small)
                            .foregroundStyle(colors.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                WalletCopyField(value: address)
            }
            .padding(16)
            .background(colors.bgElevated.opacity(0.45), in: RoundedRectangle(cornerRadius: radii.lg))
            .overlay(RoundedRectangle(cornerRadius: radii.lg).stroke(colors.borderSoft, lineWidth: 1))

            WalletQRCode(value: "\(chain.chainId.rawValue):\(address)")

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(colors.textSecondary)
                    .padding(.top, 1)
                Text("Only send assets on \(chain.title) to this address.")
                    .font(PirateTokens.Typography.body)
                    .foregroundStyle(colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(colors.bgElevated.opacity(0.45), in: RoundedRectangle(cornerRadius: radii.lg))
            .overlay(RoundedRectangle(cornerRadius: radii.lg).stroke(colors.borderSoft, lineWidth: 1))
        }
        .padding(.top, 24)
    }

    private var noWalletContent: some View {
        VStack(spacing: 12) {
            Text("No wallet connected")
                .font(PirateTokens.Typography.bodyStrong)
                .foregroundStyle(colors.textPrimary)
            Text("Connect a wallet before receiving assets.")
                .font(PirateTokens.Typography.body)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("Close receive sheet")
                    .font(PirateTokens.Typography.bodyStrong)
                    .foregroundStyle(colors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(colors.accentBrand, in: RoundedRectangle(cornerRadius: radii.lg))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(colors.bgElevated.opacity(0.45), in: RoundedRectangle(cornerRadius: radii.lg))
        .overlay(RoundedRectangle(cornerRadius: radii.lg).stroke(colors.borderSoft, lineWidth: 1))
        .padding(.top, 24)
    }
}

private struct ChainIconMark: View {
    let chainId: WalletChainId
    let size: CGFloat
    let framed: Bool

    var body: some View {
        if framed {
            WalletIconCircle(kind: iconKind, size: size, iconSize: size * 0.72, padding: 4)
        } else {
            icon
                .frame(width: size, height: size)
        }
    }

    private var iconKind: WalletIconKind {
        if chainId == .bitcoin { return .bitcoin }
        if let iconName = chainId.iconName { return .asset(iconName) }
        return .fallback(chainId.title)
    }

    @ViewBuilder
    private var icon: some View {
        switch iconKind {
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
        case .bitcoin:
            Circle()
                .fill(Color(red: 0xF7 / 255.0, green: 0x93 / 255.0, blue: 0x1A / 255.0))
                .overlay(
                    Image(systemName: "bitcoinsign")
                        .font(.system(size: size * 0.48, weight: .bold))
                        .foregroundStyle(.white)
                )
        case .fallback(let label):
            Text(String(label.prefix(1)).uppercased())
                .font(.system(size: size * 0.48, weight: .semibold))
        }
    }
}

private struct WalletCopyField: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii

    let value: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 10) {
            Text(value)
                .font(.system(size: 14, weight: .regular, design: .monospaced))
                .foregroundStyle(colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Button {
                copyToPasteboard(value)
                copied = true
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(colors.textSecondary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copied ? "Copied" : "Copy address")
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .frame(height: 44)
        .background(colors.bgPage, in: RoundedRectangle(cornerRadius: radii.md))
        .overlay(RoundedRectangle(cornerRadius: radii.md).stroke(colors.borderSoft, lineWidth: 1))
    }
}

private struct WalletQRCode: View {
    @Environment(\.pirateColors) private var colors
    @Environment(\.pirateRadii) private var radii

    let value: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radii.lg)
                .fill(.white)
            if let image = QRCodeGenerator.image(from: value) {
                QRCodeImage(image: image)
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 92))
                    .foregroundStyle(.black)
            }
        }
        .frame(width: 208, height: 208)
        .frame(maxWidth: .infinity)
        .overlay(RoundedRectangle(cornerRadius: radii.lg).stroke(colors.borderSoft, lineWidth: 1))
        .accessibilityLabel("QR code for \(value)")
    }
}

private enum QRCodeGenerator {
    static func image(from value: String) -> PlatformImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        #if canImport(UIKit)
        return UIImage(cgImage: cgImage)
        #elseif canImport(AppKit)
        return NSImage(cgImage: cgImage, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
        #else
        return nil
        #endif
    }
}

#if canImport(UIKit)
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
private typealias PlatformImage = NSImage
#endif

private struct QRCodeImage: View {
    let image: PlatformImage

    var body: some View {
        #if canImport(UIKit)
        Image(uiImage: image)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .padding(16)
        #elseif canImport(AppKit)
        Image(nsImage: image)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .padding(16)
        #endif
    }
}

private func copyToPasteboard(_ value: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = value
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
    #endif
}

private extension View {
    @ViewBuilder
    func walletSheetPresentation() -> some View {
        #if os(iOS)
        self
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        #else
        self
        #endif
    }
}

private func buildWalletChainSections(walletAddress: String?) -> [WalletChainSection] {
    let address = walletAddress?.trimmedNonEmpty

    return [
        WalletChainSection(
            chainId: .ethereum,
            title: "Ethereum",
            walletAddress: address,
            assets: [
                asset("ethereum-eth", "ETH", "Ether", .ethereum, tokenIcon: .asset("wallet_icon_ethereum")),
                asset("ethereum-usdc", "USDC", "USD Coin", .ethereum, tokenIcon: .asset("wallet_icon_usdc")),
                asset("ethereum-usdt", "USDT", "Tether USD", .ethereum, tokenIcon: .asset("wallet_icon_usdt"))
            ]
        ),
        WalletChainSection(
            chainId: .base,
            title: "Base",
            walletAddress: address,
            assets: [
                asset("base-eth", "ETH", "Ether", .base, tokenIcon: .asset("wallet_icon_ethereum")),
                asset("base-usdc", "USDC", "USD Coin", .base, tokenIcon: .asset("wallet_icon_usdc"))
            ]
        ),
        WalletChainSection(
            chainId: .optimism,
            title: "Optimism",
            walletAddress: address,
            assets: [
                asset("optimism-eth", "ETH", "Ether", .optimism, tokenIcon: .asset("wallet_icon_ethereum"))
            ]
        ),
        WalletChainSection(
            chainId: .story,
            title: "Story",
            walletAddress: address,
            assets: [
                asset("story-ip", "IP", "IP", .story, tokenIcon: .asset("wallet_icon_ip")),
                asset("story-wip", "WIP", "Wrapped IP", .story, tokenIcon: .asset("wallet_icon_ip"))
            ]
        ),
        WalletChainSection(
            chainId: .tempo,
            title: "Tempo",
            walletAddress: address,
            assets: [
                asset("tempo-pathusd", "pathUSD", "pathUSD", .tempo, tokenIcon: .asset("wallet_icon_tempo"))
            ]
        ),
        WalletChainSection(
            chainId: .bitcoin,
            title: "Bitcoin",
            walletAddress: nil,
            assets: [
                asset("bitcoin-btc", "BTC", "Bitcoin", .bitcoin, tokenIcon: .bitcoin)
            ]
        ),
        WalletChainSection(
            chainId: .solana,
            title: "Solana",
            walletAddress: nil,
            assets: [
                asset("solana-sol", "SOL", "Solana", .solana, tokenIcon: .asset("wallet_icon_solana"))
            ]
        ),
        WalletChainSection(
            chainId: .cosmos,
            title: "Cosmos",
            walletAddress: nil,
            assets: [
                asset("cosmos-atom", "ATOM", "Cosmos Hub", .cosmos, tokenIcon: .asset("wallet_icon_cosmos")),
                asset("cosmos-p2p", "P2P", "Sentinel", .cosmos, tokenIcon: .asset("wallet_icon_sentinel"))
            ]
        )
    ]
}

private func asset(
    _ id: String,
    _ symbol: String,
    _ name: String,
    _ chainId: WalletChainId,
    tokenIcon: WalletIconKind
) -> WalletAssetRow {
    WalletAssetRow(
        id: id,
        symbol: symbol,
        name: name,
        chainId: chainId,
        chainTitle: chainId.title,
        tokenIcon: tokenIcon,
        chainIcon: chainId == .bitcoin ? nil : chainId.iconName.map(WalletIconKind.asset) ?? .fallback(chainId.title),
        balance: "0",
        fiatValue: "$0.00"
    )
}

private func sortWalletAssetRows(_ left: WalletAssetRow, _ right: WalletAssetRow) -> Bool {
    let topSymbols: Set<String> = ["IP", "WIP"]
    let leftSymbol = left.symbol.uppercased()
    let rightSymbol = right.symbol.uppercased()
    let leftIsTop = topSymbols.contains(leftSymbol)
    let rightIsTop = topSymbols.contains(rightSymbol)

    if leftIsTop != rightIsTop {
        return leftIsTop
    }

    if leftIsTop && rightIsTop {
        if leftSymbol == rightSymbol {
            return left.chainTitle.localizedCompare(right.chainTitle) == .orderedAscending
        }
        return leftSymbol == "IP"
    }

    let order: [String: Int] = [
        "ETH": 0,
        "IP": 1,
        "WIP": 2,
        "USDC": 3,
        "USDT": 4,
        "DAI": 5,
        "WBTC": 6,
        "LINK": 7,
        "BTC": 8,
        "SOL": 9,
        "PATHUSD": 10
    ]

    let leftOrder = order[leftSymbol] ?? 100
    let rightOrder = order[rightSymbol] ?? 100
    if leftOrder != rightOrder {
        return leftOrder < rightOrder
    }

    let symbolCompare = left.symbol.localizedCompare(right.symbol)
    if symbolCompare != .orderedSame {
        return symbolCompare == .orderedAscending
    }

    return left.chainTitle.localizedCompare(right.chainTitle) == .orderedAscending
}

private func formatWipAmount(_ wei: String) -> String {
    let digits = wei.filter(\.isNumber)
    guard !digits.isEmpty, digits != "0" else { return "0.00" }

    let padded = String(repeating: "0", count: max(0, 19 - digits.count)) + digits
    let wholeEnd = padded.index(padded.endIndex, offsetBy: -18)
    let wholePart = String(padded[..<wholeEnd]).trimmingLeadingZeros()
    let fractionPart = String(String(padded[wholeEnd...]).prefix(4))
        .trimmingTrailingZeros()

    if fractionPart.isEmpty {
        return wholePart.isEmpty ? "0" : wholePart
    }

    return "\(wholePart.isEmpty ? "0" : wholePart).\(fractionPart)"
}

private func hasNonZeroWei(_ wei: String) -> Bool {
    wei.contains { $0.isNumber && $0 != "0" }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var shortWalletAddress: String {
        guard count > 18 else { return self }
        return "\(prefix(10))...\(suffix(6))"
    }

    func trimmingLeadingZeros() -> String {
        let trimmed = drop { $0 == "0" }
        return String(trimmed)
    }

    func trimmingTrailingZeros() -> String {
        var value = self
        while value.last == "0" {
            value.removeLast()
        }
        return value
    }
}
