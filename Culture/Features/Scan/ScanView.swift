import SwiftUI
import UIKit

/// Full-screen camera with two modes, picked from the list at bottom left:
/// - **Scan**: live on-device object detection, then a still is identified and matched to a story.
/// - **Photo**: a plain photo, pinned to the map where it was taken and filed under the nearest site.
/// Thumb rail on the right: zoom stops, shutter, flip, last photo. Pinch anywhere to zoom.
/// Falls back to a simulated viewfinder where there's no camera (Simulator, previews).
struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(Router.self) private var router
    @Environment(LibraryStore.self) private var library
    @Environment(PhotoStore.self) private var photos
    @Environment(LocationProvider.self) private var location
    @State private var model: ScanViewModel
    @State private var camera = CameraController()
    @State private var sites: [Story] = []
    @State private var viewing: PhotoViewerItem?
    @State private var pinchBase: CGFloat?
    @State private var shutterBlink = 0.0
    /// Scan mode's lock-on ring (0…1) while a subject is held steady.
    @State private var lockProgress: CGFloat = 0

    /// After closing a result, don't instantly re-identify what's still in view.
    @State private var resumeAutoScan = Date.distantPast
    /// A site just captured for the first time (Odyssey).
    @State private var celebrating: Story?

    /// Seconds a subject must stay in view before it's identified.
    private static let holdSteady = 1.2

    init(mode: CaptureMode = .scan) {
        let model = ScanViewModel()
        model.mode = mode
        _model = State(initialValue: model)
    }

    var body: some View {
        ZStack {
            // Pinch anywhere on the feed to zoom.
            Color.clear
                .contentShape(Rectangle())
                .gesture(pinchToZoom)

            reticle

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: Spacing.lg)
                HStack(alignment: .bottom, spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        caption
                        ModePicker(mode: modeBinding)
                    }
                    Spacer(minLength: 0)
                    rail
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { CameraBackground(camera: camera) }
        .overlay {
            // Shutter blink in Photo mode.
            Color.white.opacity(shutterBlink).ignoresSafeArea().allowsHitTesting(false)
        }
        .overlay {
            if let celebrating {
                SiteCapturedCelebration(
                    story: celebrating,
                    onContinue: { withAnimation(Motion.smooth) { self.celebrating = nil } },
                    onOpenOdyssey: {
                        self.celebrating = nil
                        router.openAfterDismiss(.odyssey, in: .library)
                        router.isScanPresented = false
                    }
                )
                .transition(.opacity)
            }
        }
        // Photo mode: celebrate a newly captured site straight away. (Scan mode
        // waits for its result sheet to close — see `resultBinding`.)
        .onChange(of: photos.newlyCapturedSite) {
            guard model.mode == .photo else { return }
            celebrateNewSite()
        }
        .preferredColorScheme(.dark)
        .task { await camera.start() }
        .task { sites = (try? await services.stories.allStories()) ?? MockData.stories }
        // Scan mode identifies on its own: no shutter to press.
        .task(id: autoScanKey) { await autoScan() }
        .task(id: model.photoMessage) {
            guard model.photoMessage != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(Motion.smooth) { model.photoMessage = nil }
        }
        .onDisappear { camera.stop() }
        .onChange(of: model.isFlashOn) { updateTorch() }
        .onChange(of: model.mode) { updateTorch() }
        .onChange(of: model.shutterCount) { blink() }
        .sensoryFeedback(.impact(weight: .medium), trigger: model.shutterCount)
        .sensoryFeedback(.selection, trigger: model.mode)
        .fullScreenCover(item: $viewing) { item in
            PhotoViewer(
                item: item,
                onOpenStory: { id in
                    viewing = nil
                    if let story = sites.first(where: { $0.id == id }) ?? MockData.story(id) { open(story) }
                },
                onShowOnMap: { photo in
                    viewing = nil
                    showOnMap(photo)
                }
            )
        }
        #if DEBUG
        .onAppear {
            if let id = UserDefaults.standard.string(forKey: "debugScanResult"), let story = MockData.story(id) {
                model.phase = .recognized(story)
            }
        }
        #endif
        .sheet(isPresented: resultBinding) {
            if case .recognized(let story) = model.phase {
                ScanResultSheet(story: story, pinnedPhoto: model.pinnedPhoto,
                                onOpen: { open(story) }, onRescan: model.reset,
                                onShowOnMap: { showOnMap(model.pinnedPhoto) })
            }
        }
    }

    private var instruction: String {
        switch model.phase {
        case .aiming:
            if camera.status == .unauthorized { return "Camera access is off. Allow it in Settings to scan." }
            if let object = camera.detections.first { return "\(object.displayLabel) found. Hold steady…" }
            return "Point at a statue, temple or relic. It's identified automatically."
        case .recognizing:
            return "Reading the stone…"
        case .recognized:
            return "Found."
        case .failed:
            if let hint = model.failureHint { return "No story matches this yet. \(hint)." }
            return "We couldn't read that. Try again in better light."
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: Spacing.xs) {
            Button { model.isFlashOn.toggle() } label: {
                Image(systemName: model.isFlashOn ? "bolt.fill" : "bolt.slash")
                    .font(.system(size: 16, weight: .regular))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                    .glassSurface(in: Circle())
                    .contentShape(Circle())
            }
            .disabled(camera.capabilities.position == .front)
            .accessibilityLabel(model.isFlashOn ? "Turn flash off" : "Turn flash on")

            if let chip = statusChip {
                Text(chip)
                    .font(.caption.weight(.bold))
                    .tracking(0.6)
                    .lineLimit(1)
                    .padding(.horizontal, Spacing.sm)
                    .frame(height: HitTarget.minimum)
                    .glassSurface(in: Capsule())
                    .transition(.opacity)
            }

            Spacer(minLength: Spacing.sm)
            CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
        }
        .foregroundStyle(Palette.ink)
        .padding(.top, Spacing.xs)
        .animation(Motion.smooth, value: statusChip)
    }

    /// Small live status beside the flash: what's in view (Scan) or which site a photo will be filed under (Photo).
    private var statusChip: String? {
        switch model.mode {
        case .scan:
            guard model.phase == .aiming, let object = camera.detections.first else { return nil }
            return "\(object.displayLabel.uppercased()) IN VIEW"
        case .photo:
            guard let here = location.lastLocation,
                  let site = ScanViewModel.nearestSite(to: GeoPoint(here.coordinate), in: sites) else { return "PINS TO YOUR MAP" }
            return "AT \(site.title.uppercased())"
        }
    }

    // MARK: Viewfinder

    @ViewBuilder
    private var reticle: some View {
        switch model.mode {
        case .scan:
            ViewfinderFrame(isScanning: model.phase == .recognizing, lock: lockProgress)
                .frame(width: 224, height: 280)
                .offset(y: -90) // clear of the thumb rail
                // Step back while live boxes are showing, so the two don't compete.
                .opacity(camera.detections.isEmpty || model.phase == .recognizing ? 1 : 0.35)
                .animation(Motion.smooth, value: camera.detections.isEmpty)
                .allowsHitTesting(false)
                .transition(.scale(scale: 1.15).combined(with: .opacity))
        case .photo:
            CornerBrackets(length: 16)
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: 1.5, lineCap: .square))
                .frame(width: 70, height: 70)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }

    /// Instruction (Scan) or the last photo's result (Photo), above the mode list.
    @ViewBuilder
    private var caption: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(model.mode == .scan ? instruction : (model.photoMessage ?? "Every photo is pinned where you take it."))
                .textStyle(.callout)
                .foregroundStyle(Palette.ink)
                .shadow(color: .black.opacity(0.6), radius: 4)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .animation(Motion.smooth, value: model.phase)
                .animation(Motion.smooth, value: model.photoMessage)
            if camera.status == .unauthorized {
                Button("Open Settings", action: openSettings)
                    .buttonStyle(.secondary)
                    .frame(maxWidth: 200)
            }
        }
        .frame(maxWidth: 220, alignment: .leading)
    }

    // MARK: Thumb rail

    private var rail: some View {
        VStack(spacing: Spacing.sm) {
            VStack(spacing: Spacing.xxs) {
                ForEach(camera.capabilities.zoomStops.reversed(), id: \.self) { stop in
                    zoomButton(stop)
                }
                // Scan mode identifies automatically, so only Photo mode has a shutter.
                if model.mode == .photo {
                    shutter
                        .padding(.top, Spacing.xs)
                        .transition(.scale(scale: 0.6, anchor: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: model.mode)
            .padding(.top, Spacing.sm)
            .padding([.horizontal, .bottom], 5)
            .background(Color.black.opacity(0.4), in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.ink.opacity(0.1), lineWidth: 0.75))

            Button { Task { await camera.flip() } } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 52, height: 52)
                    .background(Color.black.opacity(0.4), in: Circle())
            }
            .buttonStyle(.pressable)
            .disabled(model.phase == .recognizing)
            .accessibilityLabel(camera.capabilities.position == .back ? "Switch to front camera" : "Switch to back camera")

            lastPhotoButton
        }
        .frame(width: 72)
    }

    private func zoomButton(_ stop: CGFloat) -> some View {
        let stops = camera.capabilities.zoomStops
        let active = stops.last { $0 <= camera.zoom + 0.01 } ?? stops.first
        let isActive = stop == active
        // The active stop shows the live value while pinching (e.g. "1.4×").
        let label = Self.zoomLabel(isActive ? camera.zoom : stop)

        return Button { camera.setZoom(stop) } label: {
            Text(label)
                .font(.system(size: isActive ? 13 : 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(isActive ? Palette.onAccent : Palette.inkSecondary)
                .frame(width: 44, height: 44)
                .background { if isActive { Circle().fill(Palette.ink) } }
        }
        .buttonStyle(.plain)
        .animation(Motion.snappy, value: isActive)
        .accessibilityLabel("Zoom \(label)")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    /// ".5×", "1×", "1.4×"
    static func zoomLabel(_ value: CGFloat) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded < 1 { return String(format: "%.1f×", rounded).replacingOccurrences(of: "0.", with: ".") }
        if rounded == rounded.rounded() { return "\(Int(rounded))×" }
        return String(format: "%.1f×", rounded)
    }

    private var isBusy: Bool { model.phase == .recognizing || model.isTakingPhoto }

    private var shutter: some View {
        Button(action: shoot) {
            ZStack {
                Capsule().strokeBorder(Palette.ink, lineWidth: 3)
                Capsule().fill(Palette.ink)
                    .padding(6)
                    .scaleEffect(isBusy ? 0.92 : 1)
                if model.phase == .recognizing {
                    ProgressView().tint(Palette.onAccent)
                } else if model.mode == .scan {
                    CaptureModeIcon(mode: .scan, size: 24)
                        .foregroundStyle(Palette.onAccent)
                        .transition(.opacity)
                }
            }
            .frame(width: 62, height: 116)
            .animation(Motion.snappy, value: isBusy)
            .animation(Motion.smooth, value: model.mode)
        }
        .buttonStyle(.pressable)
        .disabled(isBusy)
        .accessibilityLabel(model.mode == .scan ? "Scan" : "Take photo")
        .sensoryFeedback(.impact(weight: .heavy), trigger: model.phase == .recognizing)
    }

    /// Latest photo; opens the viewer (and from there the map).
    private var lastPhotoButton: some View {
        Button {
            viewing = PhotoViewerItem(photos: Array(photos.photos.prefix(30)))
        } label: {
            ZStack {
                Circle().fill(Color.black.opacity(0.4))
                if let latest = photos.photos.first {
                    SitePhotoImage(photo: latest)
                        .clipShape(Circle())
                        .id(latest.id)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 52, height: 52)
            .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
            .animation(Motion.spring, value: photos.photos.first?.id)
        }
        .buttonStyle(.pressable)
        .disabled(photos.photos.isEmpty)
        .accessibilityLabel("Your latest photos")
    }

    // MARK: Actions

    private var modeBinding: Binding<CaptureMode> {
        Binding(
            get: { model.mode },
            set: { newMode in
                guard newMode != model.mode, !isBusy else { return }
                model.reset()
                withAnimation(reduceMotion ? nil : Motion.snappy) { model.mode = newMode }
            }
        )
    }

    private var pinchToZoom: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = pinchBase ?? camera.zoom
                pinchBase = base
                camera.setZoom(base * value.magnification, animated: false)
            }
            .onEnded { _ in pinchBase = nil }
    }

    private func shoot() {
        switch model.mode {
        case .scan: capture()
        case .photo:
            Task { await model.takePhoto(camera: camera, photos: photos, location: location, sites: sites) }
        }
    }

    private func celebrateNewSite() {
        guard celebrating == nil, let id = photos.consumeNewlyCapturedSite(),
              let story = sites.first(where: { $0.id == id }) ?? MockData.story(id) else { return }
        withAnimation(Motion.smooth) { celebrating = story }
    }

    // MARK: Auto-scan

    private struct AutoScanKey: Equatable {
        let mode: CaptureMode
        let phase: ScanViewModel.Phase
        let subjectInView: Bool
        let status: CameraController.Status
    }

    private var autoScanKey: AutoScanKey {
        AutoScanKey(mode: model.mode, phase: model.phase,
                    subjectInView: !camera.detections.isEmpty, status: camera.status)
    }

    /// Scan mode: once something identifiable has stayed in view for a moment,
    /// identify it — the ring traces the frame meanwhile. After a miss it
    /// waits, then looks again. Without a camera (Simulator) a subject is
    /// "found" after a short pause so the flow can be tried.
    private func autoScan() async {
        lockProgress = 0
        guard model.mode == .scan else { return }

        switch model.phase {
        case .failed:
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            model.reset()
        case .aiming:
            let simulated = camera.status == .unavailable
            guard !camera.detections.isEmpty || simulated else { return }
            let wait = resumeAutoScan.timeIntervalSinceNow
            if wait > 0 {
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled else { return }
            }
            let hold = simulated ? 2.0 : Self.holdSteady
            withAnimation(reduceMotion ? nil : .linear(duration: hold)) { lockProgress = 1 }
            try? await Task.sleep(for: .seconds(hold))
            guard !Task.isCancelled, model.phase == .aiming, model.mode == .scan else { return }
            capture()
        case .recognizing, .recognized:
            return
        }
    }

    private func capture() {
        Task { await model.capture(using: services.scanner, camera: camera, photos: photos, location: location) }
    }

    /// Torch for live scanning only; Photo mode fires the flash with the shot instead.
    private func updateTorch() {
        camera.setTorch(model.isFlashOn && model.mode == .scan)
    }

    private func blink() {
        guard model.mode == .photo else { return }
        shutterBlink = 0.7
        withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.35)) { shutterBlink = 0 }
    }

    /// Closes the camera and opens the user's map (on the Library tab), optionally on a photo.
    private func showOnMap(_ photo: SitePhoto?) {
        if case .recognized(let story) = model.phase { library.recordScan(of: story.id) }
        // Pushed once the camera has fully closed (see Router.openAfterDismiss).
        router.openAfterDismiss(.map(focus: photo?.id, site: photo?.storyID), in: .library)
        router.isScanPresented = false
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }

    private var resultBinding: Binding<Bool> {
        Binding(
            get: { if case .recognized = model.phase { true } else { false } },
            set: {
                if !$0, case .recognized = model.phase {
                    resumeAutoScan = .now.addingTimeInterval(4)
                    model.reset()
                    celebrateNewSite()
                }
            }
        )
    }

    private func open(_ story: Story) {
        library.recordScan(of: story.id)
        router.openAfterDismiss(.story(story.id), in: .home)
        router.isScanPresented = false
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

/// Corner brackets with a lock-on ring while holding steady, and a sweeping
/// scan line while recognising.
private struct ViewfinderFrame: View {
    var isScanning: Bool
    /// 0…1: how far the auto-scan lock-on has got.
    var lock: CGFloat = 0
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
                // Traces round the frame as the subject is held steady.
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .trim(from: 0, to: lock)
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .shadow(color: Palette.imageWarmth.opacity(0.6), radius: 6)
                    .padding(-6)
                    .opacity(lock > 0 && !isScanning ? 1 : 0)
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
    var length: CGFloat = 28

    func path(in r: CGRect) -> Path {
        let l = length
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + l)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + l, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - l, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + l))
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - l)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX - l, y: r.maxY))
        p.move(to: CGPoint(x: r.minX + l, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - l))
        return p
    }
}

/// Vertical mode list (bottom left): the current mode large, the others small.
/// Tap a mode, or swipe up/down on the list, to switch.
private struct ModePicker: View {
    @Binding var mode: CaptureMode

    private let modes = CaptureMode.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(modes) { item in
                let isSelected = item == mode
                Button { mode = item } label: {
                    HStack(spacing: Spacing.sm) {
                        CaptureModeIcon(mode: item, size: isSelected ? 26 : 18)
                            .foregroundStyle(isSelected ? Palette.onAccent : Palette.ink)
                            .frame(width: isSelected ? 60 : 44, height: isSelected ? 60 : 44)
                            .background {
                                if isSelected {
                                    Circle().fill(Palette.ink)
                                } else {
                                    Circle().fill(Color.black.opacity(0.4))
                                        .overlay(Circle().strokeBorder(Palette.ink.opacity(0.3), lineWidth: 0.75))
                                }
                            }
                            .shadow(color: .black.opacity(isSelected ? 0.4 : 0), radius: 6, y: 2)
                        if isSelected {
                            Text(item.title.uppercased())
                                .font(.caption.weight(.bold))
                                .tracking(1.2)
                                .foregroundStyle(Palette.ink)
                                .shadow(color: .black.opacity(0.6), radius: 4)
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
            }
        }
        .animation(Motion.snappy, value: mode)
        .gesture(
            DragGesture(minimumDistance: 12).onEnded { value in
                guard let index = modes.firstIndex(of: mode) else { return }
                // Swiping up brings the next mode (below) up into place.
                if value.translation.height < -20, index + 1 < modes.count { mode = modes[index + 1] }
                if value.translation.height > 20, index > 0 { mode = modes[index - 1] }
            }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Camera mode")
        .accessibilityValue(mode.title)
        .accessibilityHint("Scan identifies a site. Photo just takes a picture and pins it to your map.")
        .accessibilityAdjustableAction { direction in
            guard let index = modes.firstIndex(of: mode) else { return }
            switch direction {
            case .increment: if index + 1 < modes.count { mode = modes[index + 1] }
            case .decrement: if index > 0 { mode = modes[index - 1] }
            @unknown default: break
            }
        }
    }
}

/// Mode glyphs. Scan: a temple framed by a viewfinder (identify a site).
/// Photo: a camera aperture (just take the picture).
struct CaptureModeIcon: View {
    let mode: CaptureMode
    var size: CGFloat = 22

    var body: some View {
        Group {
            switch mode {
            case .scan:
                ZStack {
                    Image(systemName: "viewfinder")
                        .font(.system(size: size, weight: .light))
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: size * 0.42, weight: .semibold))
                }
            case .photo:
                Image(systemName: "camera.aperture")
                    .font(.system(size: size, weight: .regular))
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Scan") {
    ScanView()
        .previewEnvironment()
}

#Preview("Photo") {
    ScanView(mode: .photo)
        .previewEnvironment()
}
