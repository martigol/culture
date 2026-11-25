//
//  SplashView.swift
//  Culture
//
//  Created by Mario Martinelli on 25/11/2026.
//

import SwiftUI

/// Launch animation in the style of Twitter / X: the mark sits on black,
/// dips back for a beat, then rushes forward — and the app is revealed
/// through it as it grows past the screen edges.
///
/// The mark is a medallion of Apollo with his sun-disc halo (from "The Old
/// Gods"). The system launch screen is the same black (LaunchBackground), so
/// the hand-over is seamless. Under Reduce Motion it simply fades.
struct SplashView: View {
    /// `false` holds the mark on screen (previews / design review).
    var animates = true
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var scale: CGFloat = 0.9
    @State private var isRevealing = false
    @State private var curtainOpacity = 1.0
    @State private var glow = false

    private let size: CGFloat = 136

    var body: some View {
        GeometryReader { geo in
            // Big enough that the circle's edge clears every corner.
            let fullScale = hypot(geo.size.width, geo.size.height) / size * 1.1

            ZStack {
                curtain
                    .opacity(curtainOpacity)

                VStack(spacing: Spacing.xl) {
                    medallion
                        .scaleEffect(scale)
                        .opacity(isRevealing ? 0 : (appeared ? 1 : 0))
                    Text("CLIO")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(9)
                        .foregroundStyle(Palette.inkSecondary)
                        .opacity(appeared && scale >= 1 && !isRevealing ? 1 : 0)
                }
                .offset(y: Spacing.xl / 2 + 8) // keep the medallion itself dead centre
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .task { await play(fullScale: fullScale) }
        }
        .ignoresSafeArea()
        .allowsHitTesting(!isRevealing)
        .accessibilityElement()
        .accessibilityLabel("Clio")
    }

    /// Black, with a circular window that opens up as the medallion grows.
    private var curtain: some View {
        Palette.background
            .mask {
                Rectangle()
                    .overlay {
                        Circle()
                            .frame(width: size, height: size)
                            .scaleEffect(scale)
                            .opacity(isRevealing ? 1 : 0)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
    }

    private var medallion: some View {
        Image(GodPlate.apolloSun.rawValue)
            .resizable()
            .scaledToFill()
            // Frame Apollo's face and the sun disc behind it.
            .frame(width: size * 1.55, height: size * 1.94)
            .offset(y: size * 0.36)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle().strokeBorder(
                    LinearGradient(colors: [Palette.ink.opacity(0.9), Palette.ink.opacity(0.15)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.5
                )
            )
            .background {
                // Soft sun-glow behind the mark, breathing while it waits.
                Circle()
                    .fill(Palette.imageWarmth.opacity(glow ? 0.38 : 0.18))
                    .blur(radius: 34)
                    .scaleEffect(glow ? 1.6 : 1.3)
            }
            .shadow(color: .black.opacity(0.6), radius: 20, y: 8)
    }

    private func play(fullScale: CGFloat) async {
        guard animates else {
            appeared = true
            scale = 1
            return
        }
        if reduceMotion {
            appeared = true
            scale = 1
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.easeOut(duration: 0.35)) { curtainOpacity = 0; isRevealing = true }
            try? await Task.sleep(for: .milliseconds(380))
            onFinished()
            return
        }

        // 1. The mark arrives.
        withAnimation(.easeOut(duration: 0.4)) { appeared = true; scale = 1 }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { glow = true }
        try? await Task.sleep(for: .milliseconds(750))

        // 2. A short dip back — the anticipation beat.
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { scale = 0.84 }
        try? await Task.sleep(for: .milliseconds(260))

        // 3. Rush forward; the app shows through the opening circle.
        isRevealing = true
        withAnimation(.timingCurve(0.7, 0, 0.84, 0, duration: 0.55)) { scale = fullScale }
        try? await Task.sleep(for: .milliseconds(560))
        onFinished()
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
