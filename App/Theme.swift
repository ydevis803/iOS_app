import SwiftUI

// MARK: - FreshTrack Design System — "The Culinary Atelier"
// Extracted from HTML/CSS assets & DESIGN.md

// MARK: - Color Palette (Material Design 3 Tonal)

extension Color {
    // Primary
    static let ftPrimary = Color(hex: 0x006E1C)
    static let ftOnPrimary = Color.white
    static let ftPrimaryContainer = Color(hex: 0x4CAF50)
    static let ftOnPrimaryContainer = Color(hex: 0x003C0B)
    static let ftPrimaryFixed = Color(hex: 0x94F990)
    static let ftPrimaryFixedDim = Color(hex: 0x78DC77)
    static let ftOnPrimaryFixed = Color(hex: 0x002204)
    static let ftOnPrimaryFixedVariant = Color(hex: 0x005313)
    static let ftInversePrimary = Color(hex: 0x78DC77)

    // Secondary
    static let ftSecondary = Color(hex: 0x42673F)
    static let ftOnSecondary = Color.white
    static let ftSecondaryContainer = Color(hex: 0xC3EEBB)
    static let ftOnSecondaryContainer = Color(hex: 0x486D45)
    static let ftSecondaryFixed = Color(hex: 0xC3EEBB)
    static let ftSecondaryFixedDim = Color(hex: 0xA8D1A1)
    static let ftOnSecondaryFixed = Color(hex: 0x002204)
    static let ftOnSecondaryFixedVariant = Color(hex: 0x2B4F2A)

    // Tertiary
    static let ftTertiary = Color(hex: 0xA63360)
    static let ftOnTertiary = Color.white
    static let ftTertiaryContainer = Color(hex: 0xF26F9D)
    static let ftOnTertiaryContainer = Color(hex: 0x690034)
    static let ftTertiaryFixed = Color(hex: 0xFFD9E2)
    static let ftTertiaryFixedDim = Color(hex: 0xFFB1C7)
    static let ftOnTertiaryFixed = Color(hex: 0x3E001C)
    static let ftOnTertiaryFixedVariant = Color(hex: 0x861948)

    // Error
    static let ftError = Color(hex: 0xBA1A1A)
    static let ftOnError = Color.white
    static let ftErrorContainer = Color(hex: 0xFFDAD6)
    static let ftOnErrorContainer = Color(hex: 0x93000A)

    // Surface / Background
    static let ftSurface = Color(hex: 0xF9F9F9)
    static let ftSurfaceBright = Color(hex: 0xF9F9F9)
    static let ftSurfaceDim = Color(hex: 0xDADADA)
    static let ftSurfaceContainerLowest = Color.white
    static let ftSurfaceContainerLow = Color(hex: 0xF3F3F3)
    static let ftSurfaceContainer = Color(hex: 0xEEEEEE)
    static let ftSurfaceContainerHigh = Color(hex: 0xE8E8E8)
    static let ftSurfaceContainerHighest = Color(hex: 0xE2E2E2)
    static let ftSurfaceVariant = Color(hex: 0xE2E2E2)
    static let ftSurfaceTint = Color(hex: 0x006E1C)
    static let ftBackground = Color(hex: 0xF9F9F9)

    // On Surface
    static let ftOnSurface = Color(hex: 0x1A1C1C)
    static let ftOnSurfaceVariant = Color(hex: 0x3F4A3C)
    static let ftOnBackground = Color(hex: 0x1A1C1C)

    // Outline
    static let ftOutline = Color(hex: 0x6F7A6B)
    static let ftOutlineVariant = Color(hex: 0xBECAB9)

    // Inverse
    static let ftInverseSurface = Color(hex: 0x2F3131)
    static let ftInverseOnSurface = Color(hex: 0xF1F1F1)
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Typography

struct FTFonts {
    // Headline family: Manrope
    static func headlineExtraBold(_ size: CGFloat) -> Font {
        .custom("Manrope-ExtraBold", size: size)
    }
    static func headlineBold(_ size: CGFloat) -> Font {
        .custom("Manrope-Bold", size: size)
    }
    static func headlineSemiBold(_ size: CGFloat) -> Font {
        .custom("Manrope-SemiBold", size: size)
    }

    // Body family: Inter
    static func bodyRegular(_ size: CGFloat) -> Font {
        .custom("Inter", size: size)
    }
    static func bodyMedium(_ size: CGFloat) -> Font {
        .custom("Inter-Medium", size: size)
    }
    static func bodySemiBold(_ size: CGFloat) -> Font {
        .custom("Inter-SemiBold", size: size)
    }
    static func bodyBold(_ size: CGFloat) -> Font {
        .custom("Inter-Bold", size: size)
    }

    // Label family: Inter
    static func labelSmall() -> Font {
        .custom("Inter-SemiBold", size: 10).uppercaseSmallCaps()
    }
    static func labelMedium() -> Font {
        .custom("Inter-SemiBold", size: 11).uppercaseSmallCaps()
    }

    // Semantic sizes
    static let displayLarge = headlineExtraBold(40)
    static let displayMedium = headlineExtraBold(34)
    static let headlineLarge = headlineBold(28)
    static let headlineMedium = headlineBold(24)
    static let headlineSmall = headlineBold(20)
    static let titleLarge = headlineSemiBold(20)
    static let titleMedium = bodySemiBold(18)
    static let titleSmall = bodySemiBold(14)
    static let bodyLarge = bodyRegular(16)
    static let bodyMediumFont = bodyRegular(14)
    static let bodySmall = bodyRegular(12)
    static let labelLarge = bodyBold(14)
}

// MARK: - Corner Radii (from CSS borderRadius config)

struct FTRadius {
    static let xs: CGFloat = 2        // DEFAULT: 0.125rem
    static let sm: CGFloat = 4        // lg: 0.25rem
    static let md: CGFloat = 8        // xl: 0.5rem
    static let lg: CGFloat = 12       // full: 0.75rem
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 24
    static let card: CGFloat = 12     // rounded-xl on cards
    static let section: CGFloat = 32  // rounded-[2rem] on sections
    static let navBar: CGFloat = 32   // rounded-t-[32px] on nav
    static let pill: CGFloat = 9999   // pill shapes
}

// MARK: - Spacing

struct FTSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Shadows (Ambient, low-opacity per DESIGN.md)

struct FTShadow {
    static let card = Shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 5)
    static let elevated = Shadow(color: .black.opacity(0.06), radius: 30, x: 0, y: 10)
    static let nav = Shadow(color: .black.opacity(0.04), radius: 20, x: 0, y: -5)
    static let button = Shadow(color: Color(hex: 0x006E1C, alpha: 0.2), radius: 16, x: 0, y: 8)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Gradients

struct FTGradients {
    static let primaryButton = LinearGradient(
        colors: [.ftPrimary, .ftPrimaryContainer],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let glassMorphism = LinearGradient(
        colors: [Color.white.opacity(0.4), Color.clear],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Freshness Status

enum FreshnessStatus: String, CaseIterable {
    case safe       // 5+ days
    case warning    // 2-4 days
    case critical   // 0-1 days
    case expired    // past date

    var dotColor: Color {
        switch self {
        case .safe: return .ftPrimaryFixed
        case .warning: return .ftTertiaryContainer
        case .critical: return .ftErrorContainer
        case .expired: return .ftError
        }
    }

    var chipBackground: Color {
        switch self {
        case .safe: return .ftSecondaryContainer
        case .warning: return .ftTertiaryContainer
        case .critical: return .ftErrorContainer
        case .expired: return .ftErrorContainer
        }
    }

    var chipForeground: Color {
        switch self {
        case .safe: return .ftOnSecondaryContainer
        case .warning: return .ftOnTertiaryContainer
        case .critical: return .ftOnErrorContainer
        case .expired: return .ftOnErrorContainer
        }
    }

    var label: String {
        switch self {
        case .safe: return "5+ DAYS"
        case .warning: return "2-4 DAYS"
        case .critical: return "0-1 DAYS"
        case .expired: return "EXPIRED"
        }
    }

    var stripColor: Color {
        switch self {
        case .safe: return .ftPrimaryFixed
        case .warning: return .ftTertiaryContainer
        case .critical, .expired: return .ftErrorContainer
        }
    }
}

// MARK: - Reusable View Modifiers

struct FTCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.ftSurfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.card, style: .continuous))
            .shadow(
                color: FTShadow.card.color,
                radius: FTShadow.card.radius,
                x: FTShadow.card.x,
                y: FTShadow.card.y
            )
    }
}

struct FTPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(FTFonts.titleSmall)
            .foregroundStyle(Color.ftOnPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FTSpacing.lg)
            .background(FTGradients.primaryButton)
            .clipShape(RoundedRectangle(cornerRadius: FTRadius.lg, style: .continuous))
            .shadow(
                color: FTShadow.button.color,
                radius: FTShadow.button.radius,
                x: FTShadow.button.x,
                y: FTShadow.button.y
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct FTGlassNavModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: FTRadius.navBar,
                    topTrailingRadius: FTRadius.navBar
                )
            )
            .shadow(
                color: FTShadow.nav.color,
                radius: FTShadow.nav.radius,
                x: FTShadow.nav.x,
                y: FTShadow.nav.y
            )
    }
}

// MARK: - View Extensions

extension View {
    func ftCard() -> some View {
        modifier(FTCardModifier())
    }

    func ftGlassNav() -> some View {
        modifier(FTGlassNavModifier())
    }
}
