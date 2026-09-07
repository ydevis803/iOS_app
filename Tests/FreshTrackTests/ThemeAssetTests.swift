import UIKit
import XCTest
@testable import FreshTrack

/// Guards the design system's runtime dependencies: every `Color.ft*` token must
/// resolve from the compiled asset catalog and every custom font must be registered.
/// A missing named color renders as *clear* in SwiftUI, which silently blanks the UI.
final class ThemeAssetTests: XCTestCase {
    private let appBundle = Bundle(for: FoodStore.self)

    /// Every token referenced by `Theme.swift`.
    private static let colorTokens = [
        "ftPrimary", "ftOnPrimary", "ftPrimaryContainer", "ftOnPrimaryContainer",
        "ftPrimaryFixed", "ftPrimaryFixedDim", "ftOnPrimaryFixed", "ftOnPrimaryFixedVariant",
        "ftInversePrimary",
        "ftSecondary", "ftOnSecondary", "ftSecondaryContainer", "ftOnSecondaryContainer",
        "ftSecondaryFixed", "ftSecondaryFixedDim", "ftOnSecondaryFixed", "ftOnSecondaryFixedVariant",
        "ftTertiary", "ftOnTertiary", "ftTertiaryContainer", "ftOnTertiaryContainer",
        "ftTertiaryFixed", "ftTertiaryFixedDim", "ftOnTertiaryFixed", "ftOnTertiaryFixedVariant",
        "ftError", "ftOnError", "ftErrorContainer", "ftOnErrorContainer",
        "ftSurface", "ftSurfaceBright", "ftSurfaceDim", "ftSurfaceContainerLowest",
        "ftSurfaceContainerLow", "ftSurfaceContainer", "ftSurfaceContainerHigh",
        "ftSurfaceContainerHighest", "ftSurfaceVariant", "ftSurfaceTint", "ftBackground",
        "ftOnSurface", "ftOnSurfaceVariant", "ftOnBackground",
        "ftOutline", "ftOutlineVariant", "ftInverseSurface", "ftInverseOnSurface",
        "ftNavInactive"
    ]

    /// PostScript names used by `FTFonts`.
    private static let fontNames = [
        "Manrope-ExtraBold", "Manrope-Bold", "Manrope-SemiBold",
        "Inter18pt-Regular", "Inter18pt-Medium", "Inter18pt-SemiBold", "Inter18pt-Bold"
    ]

    func testEveryColorTokenResolvesFromTheAssetCatalog() {
        var missing: [String] = []
        for name in Self.colorTokens where UIColor(named: name, in: appBundle, compatibleWith: nil) == nil {
            missing.append(name)
        }
        XCTAssertTrue(missing.isEmpty, "Colors missing from the compiled asset catalog: \(missing)")
    }

    func testPrimaryColorMatchesDesignSpec() throws {
        // Design spec: primary = #006E1C
        let color = try XCTUnwrap(UIColor(named: "ftPrimary", in: appBundle, compatibleWith: nil))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(color.getRed(&r, green: &g, blue: &b, alpha: &a))
        XCTAssertEqual(Int((r * 255).rounded()), 0x00)
        XCTAssertEqual(Int((g * 255).rounded()), 0x6E)
        XCTAssertEqual(Int((b * 255).rounded()), 0x1C)
        XCTAssertEqual(a, 1, accuracy: 0.001)
    }

    func testEveryCustomFontIsRegistered() {
        var missing: [String] = []
        for name in Self.fontNames where UIFont(name: name, size: 14) == nil {
            missing.append(name)
        }
        XCTAssertTrue(missing.isEmpty, "Fonts not registered (check UIAppFonts + PostScript names): \(missing)")
    }
}
