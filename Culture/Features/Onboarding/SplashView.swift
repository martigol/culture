import SwiftUI

/// The Apollo logo and wordmark pull back, then expand together to reveal the app.
struct SplashView: View {
    var animates = true
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scale: CGFloat = 1
    @State private var inkOpacity = 1.0
    @State private var curtainOpacity = 1.0
    @State private var reveal = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Palette.background
                    .mask {
                        Rectangle()
                            .overlay {
                                brand(isMask: true)
                                    .foregroundStyle(.black)
                                    .scaleEffect(scale)
                                    .opacity(reveal ? 1 : 0)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                    }
                    .opacity(curtainOpacity)

                brand(isMask: false)
                    .foregroundStyle(Palette.ink)
                    .scaleEffect(scale)
                    .opacity(inkOpacity)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .task {
                await play(fullScale: max(geometry.size.width, geometry.size.height) / 136 * 2)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Clio")
    }

    /// Matching layouts keep the logo and lettering aligned with their reveal.
    private func brand(isMask: Bool) -> some View {
        VStack(spacing: 28) {
            ZStack {
                if isMask {
                    Circle().fill(.black)
                } else {
                    Image(GodPlate.apolloSun.rawValue)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 136 * 1.55, height: 136 * 1.94)
                        .offset(y: 136 * 0.36)
                        .frame(width: 136, height: 136)
                        .clipShape(Circle())
                        .overlay {
                            Circle().strokeBorder(Palette.ink.opacity(0.65), lineWidth: 1.5)
                        }
                }
            }
            .frame(width: 136, height: 136)

            wordmark
        }
        .fixedSize()
    }

    /// The same geometry drives both the visible lettering and its cutout.
    private var wordmark: some View {
        Text("CLIO")
            .font(.custom("Zodiak-Regular", size: 38, relativeTo: .largeTitle))
            .tracking(10)
            .fixedSize()
    }

    private func play(fullScale: CGFloat) async {
        guard animates else { return }

        do {
            try await Task.sleep(for: .milliseconds(900))
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.3), completionCriteria: .removed) {
                    inkOpacity = 0
                    curtainOpacity = 0
                } completion: {
                    onFinished()
                }
                return
            }

            withAnimation(.easeOut(duration: 0.3)) { scale = 0.86 }
            try await Task.sleep(for: .milliseconds(300))
            try Task.checkCancellation()

            // Keep the lettering visible as the zoom begins; dissolve its ink
            // to expose the app through the identical, expanding letter mask.
            reveal = true
            withAnimation(.easeOut(duration: 1.25), completionCriteria: .removed) {
                scale = fullScale
            } completion: {
                onFinished()
            }
            withAnimation(.easeOut(duration: 0.65).delay(0.12)) {
                inkOpacity = 0
            }
            // Letter counters and spaces never form a solid aperture. Fade
            // the remaining curtain after the initial zoom to finish cleanly.
            withAnimation(.easeOut(duration: 0.55).delay(0.6)) {
                curtainOpacity = 0
            }
        } catch {
            // Cancellation means the splash has left the view hierarchy.
            return
        }
    }
}

#Preview("Animation") {
    ZStack {
        ArtworkView(artwork: MockData.stories[0].artwork).ignoresSafeArea()
        SplashView {}
    }
}

#Preview("Mark") {
    SplashView(animates: false) {}
}
