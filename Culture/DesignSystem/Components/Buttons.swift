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

/// Bone-tinted glass capsule with tracked uppercase label. One per screen.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.button)
            .foregroundStyle(Palette.onAccent)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Palette.accent.opacity(0.9), in: Capsule())
            .glassSurface(in: Capsule(), tint: Palette.accent)
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

/// Clear glass capsule with a light rim.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.button)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 52)
            .glassSurface(in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

extension View {
    /// Apple's Liquid Glass behind a control (iOS 26+), reacting to touch;
    /// a frosted material with a light rim on earlier systems. `tint` colours
    /// the glass (e.g. bone for primary actions).
    @ViewBuilder
    func glassSurface<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(Self.glass(tint: tint), in: shape)
        } else {
            background {
                if let tint { shape.fill(tint) } else { shape.fill(.ultraThinMaterial) }
            }
            .overlay(shape.stroke(Palette.ink.opacity(tint == nil ? 0.25 : 0), lineWidth: 0.75))
        }
    }

    @available(iOS 26.0, *)
    private static func glass(tint: Color?) -> Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        return glass.interactive()
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle { static var primary: Self { .init() } }
extension ButtonStyle where Self == SecondaryButtonStyle { static var secondary: Self { .init() } }
extension ButtonStyle where Self == PressableStyle { static var pressable: Self { .init() } }

/// Round glass icon button for use over imagery (close, flash).
struct CircleIconButton: View {
    let systemName: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .light))
                .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                .glassSurface(in: Circle())
                .contentShape(Circle())
        }
        .accessibilityLabel(label)
    }
}
