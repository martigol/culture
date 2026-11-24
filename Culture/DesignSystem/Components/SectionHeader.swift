import SwiftUI

/// Inscribed section label with a hairline rule:  MYTHS & LEGENDS ———— See all
struct SectionHeader: View {
    let title: String
    var actionTitle: String? = "See all"
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text(title)
                .textStyle(.section)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
                .layoutPriority(1)
            Rectangle()
                .fill(Palette.hairline)
                .frame(height: 0.5)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .textStyle(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(minHeight: HitTarget.minimum)
                    .layoutPriority(1)
            }
        }
        .frame(minHeight: HitTarget.minimum)
        .padding(.horizontal, Spacing.screen)
    }
}
