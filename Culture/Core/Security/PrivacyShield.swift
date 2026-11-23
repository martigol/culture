import SwiftUI

/// Blurs app content when the app is inactive / in the App Switcher so
/// sensitive screens are not captured in the system snapshot.
struct PrivacyShield: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .overlay {
                if scenePhase != .active {
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        BrandMark(size: 56)
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: scenePhase)
    }
}

extension View {
    func privacyShield() -> some View { modifier(PrivacyShield()) }
}
