//
//  GlassCard.swift
//  Culture
//
//  Created by Mario Martinelli on 25/11/2026.
//

import SwiftUI

extension View {
    /// Glowing glass card: curved edges, a frosted (Liquid Glass on iOS 26)
    /// body, a light-catching rim, and a soft glow taken from `glow` — the
    /// card's own artwork, blurred behind it — so each card tints the page
    /// around it.
    func glassCard(cornerRadius: CGFloat = Radius.card, glow: Artwork? = nil) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, glow: glow))
    }
}

private struct GlassCard: ViewModifier {
    let cornerRadius: CGFloat
    let glow: Artwork?

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }

    func body(content: Content) -> some View {
        content
            .clipShape(shape)
            .background { glassBody }
            .overlay { rim }
            .background { glowLayer }
            .shadow(color: .black.opacity(0.45), radius: 18, y: 10)
    }

    @ViewBuilder
    private var glassBody: some View {
        if #available(iOS 26.0, *) {
            shape.fill(Palette.surface.opacity(0.25)).glassEffect(.regular, in: shape)
        } else {
            shape.fill(.ultraThinMaterial)
                .overlay(shape.fill(Palette.surface.opacity(0.35)))
        }
    }

    /// Bright at the top-left, fading round the edge, like light on a glass slab.
    private var rim: some View {
        shape.strokeBorder(
            LinearGradient(
                colors: [Palette.ink.opacity(0.55), Palette.ink.opacity(0.06), Palette.ink.opacity(0.22)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            lineWidth: 1
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var glowLayer: some View {
        if let glow {
            ArtworkView(artwork: glow, engraved: false, motion: false)
                .blur(radius: 44)
                .saturation(1.3)
                .opacity(0.55)
                .padding(-6)
                // Feathered edge, so the glow fades out instead of ending in a box.
                .mask(shape.inset(by: -18).blur(radius: 18))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// Small frosted capsule for labels over imagery ("1/3", "Story of the day").
struct GlassPill<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(.caption2.weight(.bold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, Spacing.xs + 2)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.ink.opacity(0.25), lineWidth: 0.75))
    }
}
