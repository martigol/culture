import SwiftUI

/// Story imagery with the brand "aged print" treatment: muted natural colour,
/// a warm bone wash and a faint engraving-line texture. Keeps any photo
/// (sample or from the backend) consistent with the palette.
///
/// Images bigger than a thumbnail also move with depth: they drift against the
/// phone's tilt and glide inside their frame while scrolling, like a print
/// behind glass. The image is drawn slightly oversized so its edges never show.
struct ArtworkView: View {
    let artwork: Artwork
    var engraved = true
    /// Tilt + scroll parallax (automatically off for thumbnails and under Reduce Motion).
    var motion = true

    /// Extra size drawn around the frame for the image to move into.
    private static let overscan: CGFloat = 1.14

    var body: some View {
        Color.clear
            .overlay { image }
            .clipped()
            .background(Palette.surface)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var image: some View {
        if let url = artwork.imageURL {
            AsyncImage(url: url) { phase in
                if let img = phase.image { treated(img) } else { treated(Image(artwork.imageName)) }
            }
        } else {
            treated(Image(artwork.imageName))
        }
    }

    private func treated(_ image: Image) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let moves = motion && side >= 100
            // Of the overscan margin (7% per side), part goes to tilt and part to scrolling.
            let margin = side * (Self.overscan - 1) / 2

            Group {
                if engraved {
                    image
                        .resizable()
                        .scaledToFill()
                        .saturation(0.6)
                        .contrast(1.1)
                        .brightness(-0.03)
                        .colorMultiply(Palette.imageWarmth)
                        .overlay(EngravingTexture(opacity: 0.14).blendMode(.multiply))
                } else {
                    image.resizable().scaledToFill()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: alignment)
            .scaleEffect(moves ? Self.overscan : 1)
            .scrollParallax(travel: margin * 0.5, enabled: moves)
            .tiltParallax(magnitude: margin * 0.45, enabled: moves)
        }
    }

    private var alignment: Alignment {
        Alignment(
            horizontal: artwork.focus.x < 0.4 ? .leading : artwork.focus.x > 0.6 ? .trailing : .center,
            vertical: artwork.focus.y < 0.4 ? .top : artwork.focus.y > 0.6 ? .bottom : .center
        )
    }
}

/// Fine horizontal hatching, like the burin lines of a copper engraving.
struct EngravingTexture: View {
    var spacing: CGFloat = 2.6
    var opacity: Double = 0.28

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var y: CGFloat = 0
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(.black.opacity(opacity)), lineWidth: 0.7)
        }
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

#Preview {
    ArtworkView(artwork: MockData.stories[2].artwork)
        .frame(height: 320)
}
