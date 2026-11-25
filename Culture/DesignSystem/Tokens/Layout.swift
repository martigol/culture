import SwiftUI

/// 8-pt spacing system. Use only these values.
///
/// Rhythm rules (apply everywhere):
/// - Screen edge margin: `Spacing.screen` (24)
/// - Between page sections: `Spacing.section` (56)
/// - Section header → its content: `Spacing.md` (16)
/// - Between related text lines (overline/title/subtitle): `Spacing.xs` (8)
/// - Between cards in a carousel / grid: `Spacing.md` (16)
/// - Card image → card text: `Spacing.sm` (12)
enum Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
    static let section: CGFloat = 56
    static let screen: CGFloat = 24
}

/// Restrained, near-square corners — prints and plates, not bubbles.
enum Radius {
    /// Glass feed cards (Home).
    static let card: CGFloat = 30
    /// Media and panels inside a glass card.
    static let cardInner: CGFloat = 22
    static let xs: CGFloat = 2
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 10
}

enum Motion {
    static let snappy = Animation.snappy(duration: 0.25)
    static let smooth = Animation.smooth(duration: 0.4)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.85)
}

/// Minimum hit target per Apple HIG.
enum HitTarget {
    static let minimum: CGFloat = 44
}
