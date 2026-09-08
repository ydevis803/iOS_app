import SwiftUI

// MARK: - FreshTrack Design System — "The Culinary Atelier"
// Extracted from HTML/CSS assets & DESIGN.md

// MARK: - Color Palette (Material Design 3 Tonal)
// Backed by Color Sets in Assets.xcassets (per §4 Xcode Readiness). The asset
// name matches each token name, enabling future light/dark variants in the catalog.

struct FTColors {
    // Primary
    static let primary = Color("ftPrimary", bundle: .main)
    static let onPrimary = Color("ftOnPrimary", bundle: .main)
    static let primaryContainer = Color("ftPrimaryContainer", bundle: .main)
    static let onPrimaryContainer = Color("ftOnPrimaryContainer", bundle: .main)
    static let primaryFixed = Color("ftPrimaryFixed", bundle: .main)
    static let primaryFixedDim = Color("ftPrimaryFixedDim", bundle: .main)
    static let onPrimaryFixed = Color("ftOnPrimaryFixed", bundle: .main)
    static let onPrimaryFixedVariant = Color("ftOnPrimaryFixedVariant", bundle: .main)
    static let inversePrimary = Color("ftInversePrimary", bundle: .main)

    // Secondary
    static let secondary = Color("ftSecondary", bundle: .main)
    static let onSecondary = Color("ftOnSecondary", bundle: .main)
    static let secondaryContainer = Color("ftSecondaryContainer", bundle: .main)
    static let onSecondaryContainer = Color("ftOnSecondaryContainer", bundle: .main)
    static let secondaryFixed = Color("ftSecondaryFixed", bundle: .main)
    static let secondaryFixedDim = Color("ftSecondaryFixedDim", bundle: .main)
    static let onSecondaryFixed = Color("ftOnSecondaryFixed", bundle: .main)
    static let onSecondaryFixedVariant = Color("ftOnSecondaryFixedVariant", bundle: .main)

    // Tertiary
    static let tertiary = Color("ftTertiary", bundle: .main)
    static let onTertiary = Color("ftOnTertiary", bundle: .main)
    static let tertiaryContainer = Color("ftTertiaryContainer", bundle: .main)
    static let onTertiaryContainer = Color("ftOnTertiaryContainer", bundle: .main)
    static let tertiaryFixed = Color("ftTertiaryFixed", bundle: .main)
    static let tertiaryFixedDim = Color("ftTertiaryFixedDim", bundle: .main)
    static let onTertiaryFixed = Color("ftOnTertiaryFixed", bundle: .main)
    static let onTertiaryFixedVariant = Color("ftOnTertiaryFixedVariant", bundle: .main)

    // Error
    static let error = Color("ftError", bundle: .main)
    static let onError = Color("ftOnError", bundle: .main)
    static let errorContainer = Color("ftErrorContainer", bundle: .main)
    static let onErrorContainer = Color("ftOnErrorContainer", bundle: .main)

    // Surface / Background
    static let surface = Color("ftSurface", bundle: .main)
    static let surfaceBright = Color("ftSurfaceBright", bundle: .main)
    static let surfaceDim = Color("ftSurfaceDim", bundle: .main)
    static let surfaceContainerLowest = Color("ftSurfaceContainerLowest", bundle: .main)
    static let surfaceContainerLow = Color("ftSurfaceContainerLow", bundle: .main)
    static let surfaceContainer = Color("ftSurfaceContainer", bundle: .main)
    static let surfaceContainerHigh = Color("ftSurfaceContainerHigh", bundle: .main)
    static let surfaceContainerHighest = Color("ftSurfaceContainerHighest", bundle: .main)
    static let surfaceVariant = Color("ftSurfaceVariant", bundle: .main)
    static let surfaceTint = Color("ftSurfaceTint", bundle: .main)
    static let background = Color("ftBackground", bundle: .main)

    // On Surface
    static let onSurface = Color("ftOnSurface", bundle: .main)
    static let onSurfaceVariant = Color("ftOnSurfaceVariant", bundle: .main)
    static let onBackground = Color("ftOnBackground", bundle: .main)

    // Outline
    static let outline = Color("ftOutline", bundle: .main)
    static let outlineVariant = Color("ftOutlineVariant", bundle: .main)

    // Inverse
    static let inverseSurface = Color("ftInverseSurface", bundle: .main)
    static let inverseOnSurface = Color("ftInverseOnSurface", bundle: .main)

    // Navigation
    static let navInactive = Color("ftNavInactive", bundle: .main)
}

// MARK: - Hex Color Initializer
// Retained for one-off decorative values (e.g. shadow tints) that aren't design tokens.

extension Color {
    /// Creates a color from a 24-bit `0xRRGGBB` hex value and optional opacity.
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

/// Typography scale for the design system: Manrope for headlines, Inter for body/labels,
/// exposed both as family helpers and named semantic sizes.
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
        .custom("Inter18pt-Regular", size: size)
    }
    static func bodyMedium(_ size: CGFloat) -> Font {
        .custom("Inter18pt-Medium", size: size)
    }
    static func bodySemiBold(_ size: CGFloat) -> Font {
        .custom("Inter18pt-SemiBold", size: size)
    }
    static func bodyBold(_ size: CGFloat) -> Font {
        .custom("Inter18pt-Bold", size: size)
    }

    // Label family: Inter
    static func labelSmall() -> Font {
        .custom("Inter18pt-SemiBold", size: 10).uppercaseSmallCaps()
    }
    static func labelMedium() -> Font {
        .custom("Inter18pt-SemiBold", size: 11).uppercaseSmallCaps()
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

/// Named corner-radius constants used across the design system.
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

/// Named spacing constants for consistent padding and stack spacing.
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

/// Named ambient shadow presets for cards, elevated surfaces, the nav bar, and buttons.
struct FTShadow {
    static let card = Shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 5)
    static let elevated = Shadow(color: .black.opacity(0.06), radius: 30, x: 0, y: 10)
    static let nav = Shadow(color: .black.opacity(0.04), radius: 20, x: 0, y: -5)
    static let button = Shadow(color: Color.ftPrimary.opacity(0.2), radius: 16, x: 0, y: 8)
}

/// Plain shadow parameters, since SwiftUI has no first-class shadow value type.
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Gradients

/// Reusable gradients for primary buttons and glassmorphism overlays.
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

/// Freshness band of an item, with the colors and label used to present it.
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

/// Applies the standard card surface, corner radius, and ambient shadow.
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

/// Primary call-to-action button style: gradient fill, shadow, and press feedback.
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

/// Applies the glassmorphism (ultra-thin material) treatment to the bottom nav bar.
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
    /// Wraps the view in the standard card surface (``FTCardModifier``).
    func ftCard() -> some View {
        modifier(FTCardModifier())
    }

    /// Applies the glassmorphism nav-bar treatment (``FTGlassNavModifier``).
    func ftGlassNav() -> some View {
        modifier(FTGlassNavModifier())
    }
}
