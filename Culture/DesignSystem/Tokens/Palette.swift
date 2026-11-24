import SwiftUI
import UIKit

/// "Engraving" palette — bone ink on black, like a classical copperplate print.
///
/// Strictly monochrome: one warm neutral ramp + black. Photography gets a
/// matching warm treatment in `ArtworkView`, so imagery and UI read as one.
///
/// The brand is **dark-only**: these values are fixed (not light/dark adaptive),
/// so the app, Xcode previews and sheets always render on black even when the
/// device or canvas is in light mode. `CultureApp` also pins `.dark` so system
/// controls (keyboard, menus, search field) match.
///
/// Never hard-code colours in features — use these tokens.
enum Palette {
    // MARK: Surfaces
    static let background = Color(hex: 0x0A0908)
    static let surface = Color(hex: 0x131110)
    static let surfaceRaised = Color(hex: 0x1B1916)
    static let hairline = Color(hex: 0x2A2622)

    // MARK: Ink
    /// Primary text and the single accent — warm bone.
    static let ink = Color(hex: 0xF3ECDF)
    static let inkSecondary = Color(hex: 0xD2C9B8)
    static let inkTertiary = Color(hex: 0xA89F90)

    /// Accent = bone. Used for primary buttons, selection, progress.
    static let accent = ink
    /// Content placed on `accent` fills.
    static let onAccent = Color(hex: 0x0A0908)

    /// Warm wash applied over imagery so photos sit in the palette
    /// while keeping a hint of their natural colour.
    static let imageWarmth = Color(hex: 0xF7ECD9)

    // MARK: Gradients
    /// Fades imagery into the page background. Uses the adaptive
    /// `background` token so it blends seamlessly in light and dark mode.
    static let fadeToBackground = LinearGradient(
        stops: [
            .init(color: background.opacity(0), location: 0.4),
            .init(color: background.opacity(0.75), location: 0.75),
            .init(color: background, location: 1),
        ],
        startPoint: .top, endPoint: .bottom
    )
}

// MARK: - Helpers

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

}
