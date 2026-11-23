import SwiftUI

// Motion toolkit. Every effect here respects Reduce Motion.
// Usage:
//   .reveal(order: 2)        staggered fade + rise on first appear
//   .carouselCard()          scale/fade as a card scrolls in a carousel
//   .parallax()              slower-moving hero image on scroll
//   .shimmer()               loading skeleton highlight
//   StoryLink(story:)        NavigationLink with iOS 18 zoom transition

// MARK: Reveal

private struct Reveal: ViewModifier {
    let delay: Double
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 24)
            .onAppear {
                guard !shown else { return }
                withAnimation(.smooth(duration: 0.7).delay(delay)) { shown = true }
            }
    }
}

extension View {
    /// Fade + rise when first shown; `order` staggers siblings by 80 ms.
    func reveal(order: Int = 0) -> some View {
        modifier(Reveal(delay: Double(order) * 0.08))
    }
}

// MARK: Scroll effects

extension View {
    /// Cards ease in as they enter a horizontal carousel.
    func carouselCard() -> some View {
        scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.93, anchor: .bottom)
                .opacity(phase.isIdentity ? 1 : 0.55)
        }
    }

    /// Rows settle in as they scroll onto screen vertically.
    func listRowEntrance() -> some View {
        scrollTransition(.animated(.smooth(duration: 0.4)), axis: .vertical) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.3)
                .offset(y: phase.value > 0 ? 16 : 0)
        }
    }

    /// Hero parallax: moves at `rate` of scroll speed and stretches on overscroll.
    /// Disabled under Reduce Motion.
    func parallax(rate: CGFloat = 0.35) -> some View {
        modifier(Parallax(rate: rate))
    }
}

private struct Parallax: ViewModifier {
    let rate: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.visualEffect { content, proxy in
                let y = proxy.frame(in: .scrollView).minY
                return content
                    .offset(y: y < 0 ? -y * rate : -y)
                    .scaleEffect(y > 0 ? 1 + y / 500 : 1, anchor: .top)
            }
        }
    }
}

// MARK: Shimmer

private struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, Palette.ink.opacity(0.08), .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: phase * geo.size.width * 1.6)
                }
                .clipped()
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1 }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

// MARK: Zoom navigation (iOS 18+, graceful fallback on 17)

private struct ZoomNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// Shared namespace for card → detail zoom transitions (set in RootView).
    var zoomNamespace: Namespace.ID? {
        get { self[ZoomNamespaceKey.self] }
        set { self[ZoomNamespaceKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let namespace {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func zoomDestination(id: some Hashable, in namespace: Namespace.ID?) -> some View {
        if #available(iOS 18.0, *), let namespace {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

/// NavigationLink to a story that zooms out of its card.
struct StoryLink<Label: View>: View {
    let story: Story
    @ViewBuilder var label: () -> Label
    @Environment(\.zoomNamespace) private var namespace

    var body: some View {
        NavigationLink(value: Route.story(story.id)) {
            label().zoomSource(id: story.id, in: namespace)
        }
        .buttonStyle(.pressable)
    }
}
