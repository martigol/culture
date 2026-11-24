import SwiftUI

/// Subtle press feedback used across tappable cards.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

/// Bone-filled plate with tracked uppercase label. One per screen.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.button)
            .foregroundStyle(Palette.onAccent)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

/// Hairline outlined plate.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.button)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 52)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(Palette.ink.opacity(0.35), lineWidth: 0.75)
            )
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle { static var primary: Self { .init() } }
extension ButtonStyle where Self == SecondaryButtonStyle { static var secondary: Self { .init() } }
extension ButtonStyle where Self == PressableStyle { static var pressable: Self { .init() } }

/// Round outlined icon button for use over imagery (close, flash).
struct CircleIconButton: View {
    let systemName: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .light))
                .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                .background(Color.black.opacity(0.35), in: Circle())
                .overlay(Circle().strokeBorder(Palette.ink.opacity(0.3), lineWidth: 0.75))
        }
        .accessibilityLabel(label)
    }
}
