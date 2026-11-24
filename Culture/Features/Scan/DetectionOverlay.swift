//
//  DetectionOverlay.swift
//  Culture
//
//  Created by Mario Martinelli on 23/11/2026.
//

import SwiftUI

/// Engraved corner ticks and a label for each object found in the live feed.
/// Maps Vision's normalised coordinates onto the aspect-filled camera preview.
struct DetectionOverlay: View {
    let detections: [DetectedObject]
    /// Pixel size of the analysed frame (portrait).
    let frameSize: CGSize

    var body: some View {
        GeometryReader { geo in
            ForEach(detections) { object in
                let rect = Self.viewRect(for: object.boundingBox, frame: frameSize, in: geo.size)
                CornerTicks()
                    .stroke(Palette.ink.opacity(0.9), style: StrokeStyle(lineWidth: 1, lineCap: .square))
                    .frame(width: rect.width, height: rect.height)
                    .overlay(alignment: .topLeading) {
                        DetectionLabel(object: object)
                            .fixedSize()
                            .alignmentGuide(.top) { $0[.bottom] + Spacing.xs }
                    }
                    .position(x: rect.midX, y: rect.midY)
                    .transition(.opacity)
            }
        }
        .animation(Motion.smooth, value: detections)
        .allowsHitTesting(false)
        .accessibilityHidden(true) // The instruction line announces what's in view.
    }

    /// Vision rect (0…1, origin bottom-left) → view rect, accounting for the
    /// aspect-fill crop the preview layer applies.
    static func viewRect(for box: CGRect, frame: CGSize, in view: CGSize) -> CGRect {
        guard frame.width > 0, frame.height > 0 else {
            return CGRect(x: box.minX * view.width, y: (1 - box.maxY) * view.height,
                          width: box.width * view.width, height: box.height * view.height)
        }
        let scale = max(view.width / frame.width, view.height / frame.height)
        let width = frame.width * scale
        let height = frame.height * scale
        let dx = (view.width - width) / 2
        let dy = (view.height - height) / 2
        return CGRect(x: dx + box.minX * width, y: dy + (1 - box.maxY) * height,
                      width: box.width * width, height: box.height * height)
    }
}

/// "Sculpture  87%" plate above a detected object.
private struct DetectionLabel: View {
    let object: DetectedObject

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(object.displayLabel)
                .foregroundStyle(Palette.ink)
            Text(object.percent)
                .monospacedDigit()
                .foregroundStyle(Palette.inkTertiary)
        }
        .textStyle(.label)
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, Spacing.xxs)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: Radius.xs))
        .overlay(RoundedRectangle(cornerRadius: Radius.xs).strokeBorder(Palette.ink.opacity(0.35), lineWidth: 0.5))
    }
}

/// Short corner ticks, scaled to the box.
private struct CornerTicks: Shape {
    func path(in r: CGRect) -> Path {
        let l = min(16, r.width / 4, r.height / 4)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + l)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + l, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - l, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + l))
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - l)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX - l, y: r.maxY))
        p.move(to: CGPoint(x: r.minX + l, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - l))
        return p
    }
}

#Preview {
    ZStack {
        ArtworkView(artwork: Artwork(imageName: "nike", credit: ""))
        DetectionOverlay(
            detections: [
                DetectedObject(id: 0, label: "sculpture", confidence: 0.87,
                               boundingBox: CGRect(x: 0.2, y: 0.25, width: 0.6, height: 0.5)),
                DetectedObject(id: 1, label: "column", confidence: 0.41,
                               boundingBox: CGRect(x: 0.05, y: 0.08, width: 0.2, height: 0.3)),
            ],
            frameSize: CGSize(width: 1080, height: 1440)
        )
    }
    .ignoresSafeArea()
    .preferredColorScheme(.dark)
}
