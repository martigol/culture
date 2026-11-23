import SwiftUI

/// Inscribed wordmark — tracked capitals, like letters cut in marble.
struct BrandHeader: View {
    var body: some View {
        Text("CultureLens")
            .font(.custom("Zodiak-Regular", size: 15, relativeTo: .headline))
            .tracking(5)
            .textCase(.uppercase)
            .foregroundStyle(Palette.ink)
            .accessibilityLabel("CultureLens")
    }
}

/// Monogram for small brand moments (privacy shield, empty states).
struct BrandMark: View {
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            Circle().strokeBorder(Palette.ink.opacity(0.5), lineWidth: 0.75)
            Text("Λ")
                .font(.custom("Zodiak-Regular", size: size * 0.48, relativeTo: .title))
                .foregroundStyle(Palette.ink)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
