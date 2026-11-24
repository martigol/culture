import CoreMotion
import SwiftUI

// Motion toolkit. Every effect here respects Reduce Motion.
// Usage:
//   .reveal(order: 2)        staggered fade + rise on first appear
//   .carouselCard()          scale/fade as a card scrolls in a carousel
//   .parallax()              slower-moving hero image on scroll
//   .tiltParallax(...)       content drifts against the phone's tilt (gyroscope)
//   .scrollParallax(...)     content drifts inside its frame while scrolling
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

// MARK: Tilt parallax

/// Device tilt from the gyroscope, smoothed, as -1…1 on each axis. The neutral
/// position slowly follows however the phone is being held, so images only
/// drift while the hand moves (like the Home Screen wallpaper). Shared, and
/// only running while at least one view uses it.
@Observable
@MainActor
final class DeviceTilt {
    static let shared = DeviceTilt()

    /// Left/right tilt (roll), -1…1.
    private(set) var x: Double = 0
    /// Forward/back tilt (pitch), -1…1.
    private(set) var y: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var users = 0
    @ObservationIgnored private var neutral: (roll: Double, pitch: Double)?

    /// Radians of tilt that reach full travel.
    private let range = 0.35

    func start() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let attitude = motion?.attitude else { return }
            let roll = attitude.roll, pitch = attitude.pitch
            MainActor.assumeIsolated { self?.update(roll: roll, pitch: pitch) }
        }
    }

    func stop() {
        users = max(users - 1, 0)
        guard users == 0 else { return }
        manager.stopDeviceMotionUpdates()
        neutral = nil
        x = 0
        y = 0
    }

    private func update(roll: Double, pitch: Double) {
        var base = neutral ?? (roll, pitch)
        // Re-centre slowly so a new grip becomes the new rest position.
        base.roll += (roll - base.roll) * 0.015
        base.pitch += (pitch - base.pitch) * 0.015
        neutral = base

        let targetX = min(max((roll - base.roll) / range, -1), 1)
        let targetY = min(max((pitch - base.pitch) / range, -1), 1)
        // Low-pass so the image glides rather than jitters.
        x += (targetX - x) * 0.2
        y += (targetY - y) * 0.2
    }
}

/// Shifts content against the device's tilt by up to `magnitude` points.
private struct TiltParallax: ViewModifier {
    let magnitude: CGFloat
    let enabled: Bool
    @State private var tilt = DeviceTilt.shared
    @State private var isRunning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isActive: Bool { enabled && !reduceMotion }

    func body(content: Content) -> some View {
        content
            .offset(x: isActive ? -tilt.x * magnitude : 0,
                    y: isActive ? -tilt.y * magnitude : 0)
            .onAppear { setRunning(isActive) }
            .onDisappear { setRunning(false) }
            .onChange(of: isActive) { setRunning(isActive) }
    }

    private func setRunning(_ run: Bool) {
        guard run != isRunning else { return }
        isRunning = run
        run ? tilt.start() : tilt.stop()
    }
}

extension View {
    /// Moves content opposite to the phone's tilt, up to `magnitude` points.
    /// Off under Reduce Motion.
    func tiltParallax(magnitude: CGFloat, enabled: Bool = true) -> some View {
        modifier(TiltParallax(magnitude: magnitude, enabled: enabled))
    }

    /// Inside a clipped frame: drifts content as its container scrolls past
    /// (vertically and in carousels), up to `travel` points each way.
    func scrollParallax(travel: CGFloat, enabled: Bool = true) -> some View {
        modifier(ScrollParallax(travel: travel, enabled: enabled))
    }
}

private struct ScrollParallax: ViewModifier {
    let travel: CGFloat
    let enabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if !enabled || reduceMotion {
            content
        } else {
            content.visualEffect { content, proxy in
                // Outside a scroll view there's no viewport, so no drift.
                let viewport = proxy.bounds(of: .scrollView)
                let frame = proxy.frame(in: .scrollView)
                // -1 at one edge of the viewport, 0 centred, 1 at the other.
                let dy = viewport.map { (frame.midY - $0.midY) / max($0.height, 1) } ?? 0
                let dx = viewport.map { (frame.midX - $0.midX) / max($0.width, 1) } ?? 0
                return content.offset(
                    x: -min(max(dx, -1), 1) * travel,
                    y: -min(max(dy, -1), 1) * travel
                )
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
