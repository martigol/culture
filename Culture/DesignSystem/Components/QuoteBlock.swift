import SwiftUI

/// Centred epigraph with the Greek original — a signature brand moment.
struct QuoteBlock: View {
    let greek: String
    let english: String
    let source: String

    var body: some View {
        VStack(spacing: Spacing.md) {
            Text(greek)
                .font(.custom("Zodiak-Italic", size: 30, relativeTo: .title))
                .foregroundStyle(Palette.ink)
            Text(english)
                .textStyle(.lede)
                .foregroundStyle(Palette.inkSecondary)
            Text(source)
                .textStyle(.label)
                .foregroundStyle(Palette.inkTertiary)
                .padding(.top, Spacing.xxs)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
        .padding(.horizontal, Spacing.screen)
        .overlay(alignment: .top) { OrnamentRule() }
        .overlay(alignment: .bottom) { OrnamentRule() }
        .padding(.horizontal, Spacing.screen)
        .accessibilityElement(children: .combine)
    }
}

/// Hairline rule with a centred diamond — a quiet classical divider.
struct OrnamentRule: View {
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Rectangle().fill(Palette.hairline).frame(height: 0.5)
            Rectangle().fill(Palette.inkTertiary).frame(width: 5, height: 5).rotationEffect(.degrees(45))
            Rectangle().fill(Palette.hairline).frame(height: 0.5)
        }
        .accessibilityHidden(true)
    }
}
