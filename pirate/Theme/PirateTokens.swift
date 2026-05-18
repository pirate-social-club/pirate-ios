import SwiftUI

struct PirateColorTokens: Sendable {
    let bgPage: Color
    let bgSurface: Color
    let bgElevated: Color
    let bgOverlay: Color
    let surfaceHoverSubtle: Color
    let surfaceSubtle: Color
    let surfaceInteractive: Color
    let surfaceSkeleton: Color
    let surfaceDisabled: Color
    let surfaceAccent: Color
    let surfaceDanger: Color
    let surfaceSuccess: Color
    let surfaceWarning: Color
    let textPrimary: Color
    let textSecondary: Color
    let textDisabled: Color
    let textOnAccent: Color
    let borderDefault: Color
    let borderSoft: Color
    let borderStrong: Color
    let accentBrand: Color
    let accentDanger: Color
    let accentSuccess: Color
    let accentWarning: Color
    let input: Color
}

struct PirateRadiusTokens: Sendable {
    let sm: CGFloat
    let md: CGFloat
    let lg: CGFloat
    let xl: CGFloat
    let x2l: CGFloat
    let x3l: CGFloat
    let full: CGFloat
}

enum PirateTokens {
    static let colors = PirateColorTokens(
        bgPage: Color(red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x24 / 255.0),
        bgSurface: Color(red: 0x1B / 255.0, green: 0x1B / 255.0, blue: 0x19 / 255.0),
        bgElevated: Color(red: 0x30 / 255.0, green: 0x30 / 255.0, blue: 0x2E / 255.0),
        bgOverlay: Color.black.opacity(0.55),
        surfaceHoverSubtle: Color(red: 0xD9 / 255.0, green: 0x77 / 255.0, blue: 0x57 / 255.0).opacity(0.08),
        surfaceSubtle: Color(red: 0xD9 / 255.0, green: 0x77 / 255.0, blue: 0x57 / 255.0).opacity(0.10),
        surfaceInteractive: Color(red: 0xD9 / 255.0, green: 0x77 / 255.0, blue: 0x57 / 255.0).opacity(0.24),
        surfaceSkeleton: Color(red: 0xD9 / 255.0, green: 0x77 / 255.0, blue: 0x57 / 255.0).opacity(0.48),
        surfaceDisabled: Color(red: 0xD9 / 255.0, green: 0x77 / 255.0, blue: 0x57 / 255.0).opacity(0.62),
        surfaceAccent: Color(red: 0xD9 / 255.0, green: 0x77 / 255.0, blue: 0x57 / 255.0).opacity(0.78),
        surfaceDanger: Color(red: 0xEF / 255.0, green: 0x44 / 255.0, blue: 0x44 / 255.0).opacity(0.15),
        surfaceSuccess: Color(red: 0x34 / 255.0, green: 0xD3 / 255.0, blue: 0x99 / 255.0).opacity(0.15),
        surfaceWarning: Color(red: 0xF5 / 255.0, green: 0x9E / 255.0, blue: 0x0B / 255.0).opacity(0.15),
        textPrimary: Color(red: 0xC3 / 255.0, green: 0xC0 / 255.0, blue: 0xB6 / 255.0),
        textSecondary: Color(red: 0xB7 / 255.0, green: 0xB5 / 255.0, blue: 0xA9 / 255.0),
        textDisabled: Color(red: 0x8A / 255.0, green: 0x88 / 255.0, blue: 0x80 / 255.0),
        textOnAccent: Color.white,
        borderDefault: Color(red: 0x3E / 255.0, green: 0x3E / 255.0, blue: 0x38 / 255.0),
        borderSoft: Color(red: 0x30 / 255.0, green: 0x30 / 255.0, blue: 0x2E / 255.0),
        borderStrong: Color(red: 0x52 / 255.0, green: 0x51 / 255.0, blue: 0x4A / 255.0),
        accentBrand: Color(red: 0xD9 / 255.0, green: 0x77 / 255.0, blue: 0x57 / 255.0),
        accentDanger: Color(red: 0xEF / 255.0, green: 0x44 / 255.0, blue: 0x44 / 255.0),
        accentSuccess: Color(red: 0x34 / 255.0, green: 0xD3 / 255.0, blue: 0x99 / 255.0),
        accentWarning: Color(red: 0xF5 / 255.0, green: 0x9E / 255.0, blue: 0x0B / 255.0),
        input: Color(red: 0x52 / 255.0, green: 0x51 / 255.0, blue: 0x4A / 255.0)
    )

    static let radii = PirateRadiusTokens(
        sm: 4, md: 8, lg: 12, xl: 14, x2l: 16, x3l: 24, full: 999
    )

    static let spacing: CGFloat = 8
    static let pageGutter: CGFloat = 16

    enum Typography {
        static let display: Font = .system(size: 36, weight: .bold, design: .default)
        static let h1: Font = .system(size: 30, weight: .semibold, design: .default)
        static let h2: Font = .system(size: 24, weight: .semibold, design: .default)
        static let h3: Font = .system(size: 20, weight: .semibold, design: .default)
        static let h4: Font = .system(size: 18, weight: .semibold, design: .default)
        static let body: Font = .system(size: 16, weight: .regular, design: .default)
        static let bodyStrong: Font = .system(size: 16, weight: .semibold, design: .default)
        static let label: Font = .system(size: 16, weight: .medium, design: .default)
        static let caption: Font = .system(size: 16, weight: .regular, design: .default)
        static let overline: Font = .system(size: 16, weight: .medium, design: .default)
        static let small: Font = .system(size: 14, weight: .regular, design: .default)
        static let smallStrong: Font = .system(size: 14, weight: .semibold, design: .default)
    }
}

private struct PirateColorsKey: EnvironmentKey {
    static let defaultValue = PirateTokens.colors
}

private struct PirateRadiiKey: EnvironmentKey {
    static let defaultValue = PirateTokens.radii
}

extension EnvironmentValues {
    var pirateColors: PirateColorTokens {
        get { self[PirateColorsKey.self] }
        set { self[PirateColorsKey.self] = newValue }
    }

    var pirateRadii: PirateRadiusTokens {
        get { self[PirateRadiiKey.self] }
        set { self[PirateRadiiKey.self] = newValue }
    }
}

struct PirateTheme: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.pirateColors, PirateTokens.colors)
            .environment(\.pirateRadii, PirateTokens.radii)
            .preferredColorScheme(.dark)
    }
}

extension View {
    func pirateTheme() -> some View {
        modifier(PirateTheme())
    }
}