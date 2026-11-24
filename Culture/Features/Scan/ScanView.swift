import SwiftUI
import UIKit

/// Full-screen camera experience: live feed with on-device object detection,
/// then a still is identified and matched to a story.
/// Falls back to a simulated viewfinder where there's no camera (Simulator, previews).
struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @Environment(Router.self) private var router
    @Environment(LibraryStore.self) private var library
    @State private var model = ScanViewModel()
    @State private var camera = CameraController()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: Spacing.lg)
            ViewfinderFrame(isScanning: model.phase == .recognizing)
                .frame(width: 264, height: 320)
                // Step back while live boxes are showing, so the two don't compete.
                .opacity(camera.detections.isEmpty || model.phase == .recognizing ? 1 : 0.35)
                .animation(Motion.smooth, value: camera.detections.isEmpty)
            Text(instruction)
                .textStyle(.lede)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .padding(.top, Spacing.xl)
                .contentTransition(.opacity)
                .animation(Motion.smooth, value: model.phase)
            if camera.status == .unauthorized {
                Button("Open Settings", action: openSettings)
                    .buttonStyle(.secondary)
                    .frame(maxWidth: 220)
                    .padding(.top, Spacing.md)
            }
            Spacer(minLength: Spacing.lg)
            controls
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { CameraBackground(camera: camera) }
        .preferredColorScheme(.dark)
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: model.isFlashOn) { _, isOn in camera.setTorch(isOn) }
        #if DEBUG
        .onAppear {
            if let id = UserDefaults.standard.string(forKey: "debugScanResult"), let story = MockData.story(id) {
                model.phase = .recognized(story)
            }
        }
        #endif
        .sheet(isPresented: resultBinding) {
            if case .recognized(let story) = model.phase {
                ScanResultSheet(story: story, onOpen: { open(story) }, onRescan: model.reset)
            }
        }
    }

    private var instruction: String {
        switch model.phase {
        case .aiming:
            if camera.status == .unauthorized { return "Camera access is off. Allow it in Settings to scan." }
            if let object = camera.detections.first { return "\(object.displayLabel) in view. Tap to identify." }
            return "Frame a statue, temple or relic."
        case .recognizing:
            return "Reading the stone…"
        case .recognized:
            return "Found."
        case .failed:
            if let hint = model.failureHint { return "No story matches this yet. \(hint)." }
            return "We couldn't read that. Try again in better light."
        }
    }

    private var topBar: some View {
        HStack {
            CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
            Spacer()
            Text("Scan").textStyle(.section).foregroundStyle(Palette.ink)
            Spacer()
            CircleIconButton(systemName: model.isFlashOn ? "bolt.fill" : "bolt",
                             label: model.isFlashOn ? "Turn flash off" : "Turn flash on") {
                model.isFlashOn.toggle()
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.top, Spacing.xs)
    }

    private var controls: some View {
        HStack {
            sideButton("Summary", symbol: "text.quote") { capture() }
            Spacer()
            Button(action: capture) {
                ZStack {
                    Circle().strokeBorder(Palette.ink.opacity(0.6), lineWidth: 1).frame(width: 80, height: 80)
                    Circle().fill(Palette.ink).frame(width: 64, height: 64)
                        .scaleEffect(model.phase == .recognizing ? 0.86 : 1)
                    if model.phase == .recognizing { ProgressView().tint(Palette.onAccent) }
                }
            }
            .buttonStyle(.pressable)
            .disabled(model.phase == .recognizing)
            .accessibilityLabel("Capture")
            .sensoryFeedback(.impact(weight: .heavy), trigger: model.phase == .recognizing)
            Spacer()
            sideButton("Nearby", symbol: "mappin") { }
        }
        .padding(.horizontal, Spacing.xs)
    }

    private func capture() { Task { await model.capture(using: services.scanner, camera: camera) } }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private func sideButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .light))
                    .frame(width: 48, height: 48)
                    .overlay(Circle().strokeBorder(Palette.ink.opacity(0.3), lineWidth: 0.75))
                Text(title).textStyle(.label)
            }
            .foregroundStyle(Palette.ink)
        }
        .frame(width: 72)
    }

    private var resultBinding: Binding<Bool> {
        Binding(
            get: { if case .recognized = model.phase { true } else { false } },
            set: { if !$0, case .recognized = model.phase { model.reset() } }
        )
    }

    private func open(_ story: Story) {
        library.recordScan(of: story.id)
        router.isScanPresented = false
        router.open(.story(story.id), in: .home)
    }
}

/// Live camera + detection boxes when available, otherwise the simulated feed.
private struct CameraBackground: View {
    let camera: CameraController

    var body: some View {
        if camera.isRunning {
            ZStack {
                CameraPreview(session: camera.session)
                DetectionOverlay(detections: camera.detections, frameSize: camera.frameSize)
                RadialGradient(colors: [.clear, .black.opacity(0.6)], center: .center, startRadius: 160, endRadius: 560)
                    .allowsHitTesting(false)
            }
            .background(Color.black)
            .ignoresSafeArea()
            .accessibilityHidden(true)
        } else {
            ViewfinderBackground()
        }
    }
}

/// Simulated camera feed (an engraved artifact) for the Simulator and previews.
private struct ViewfinderBackground: View {
    var body: some View {
        ZStack {
            ArtworkView(artwork: Artwork(imageName: "agamemnon", credit: ""))
                .opacity(0.55)
            RadialGradient(colors: [.clear, .black.opacity(0.85)], center: .center, startRadius: 120, endRadius: 520)
        }
        .background(Color.black)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Corner brackets with a sweeping scan line while recognising.
private struct ViewfinderFrame: View {
    var isScanning: Bool
    @State private var sweep = false
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CornerBrackets()
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: 1.5, lineCap: .square))
                    .scaleEffect(breathe ? 1.0 : 0.96)
                    .opacity(isScanning ? 1 : 0.85)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { breathe = true }
                    }
                if isScanning {
                    Rectangle()
                        .fill(Palette.ink.opacity(0.8))
                        .frame(height: 1)
                        .padding(.horizontal, Spacing.md)
                        .offset(y: sweep ? geo.size.height / 2 - 16 : -geo.size.height / 2 + 16)
                        .onAppear {
                            guard !reduceMotion else { return }
                            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { sweep = true }
                        }
                        .onDisappear { sweep = false }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct CornerBrackets: Shape {
    func path(in r: CGRect) -> Path {
        let l: CGFloat = 28
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + l)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + l, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - l, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + l))
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - l)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX - l, y: r.maxY))
        p.move(to: CGPoint(x: r.minX + l, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - l))
        return p
    }
}

#Preview {
    ScanView()
        .previewEnvironment()
}
