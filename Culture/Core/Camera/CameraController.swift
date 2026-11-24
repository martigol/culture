//
//  CameraController.swift
//  Culture
//
//  Created by Mario Martinelli on 23/11/2026.
//

import AVFoundation
import Observation
import UIKit

enum CameraError: LocalizedError {
    case unavailable, configurationFailed, captureFailed

    var errorDescription: String? {
        switch self {
        case .unavailable: "No camera is available on this device."
        case .configurationFailed: "The camera couldn't be configured."
        case .captureFailed: "The photo couldn't be captured."
        }
    }
}

/// What the active camera can do. Zoom values are "display" zoom, as on the
/// system Camera app: 1× is the wide lens, 0.5× the ultra-wide.
struct CameraCapabilities: Sendable, Equatable {
    var position: AVCaptureDevice.Position = .back
    /// `videoZoomFactor = display zoom × multiplier` (2 on virtual devices with an ultra-wide).
    var zoomMultiplier: CGFloat = 1
    var minZoom: CGFloat = 0.5
    var maxZoom: CGFloat = 5
    var hasFlash = false

    /// Stops shown on the zoom rail.
    var zoomStops: [CGFloat] {
        [0.5, 1, 2, 5].filter { $0 >= minZoom - 0.01 && $0 <= maxZoom + 0.01 }
    }
}

/// UI-facing camera state for the Scan screen: permission, live detections,
/// zoom, flip, torch/flash and still capture. All AVFoundation work lives in `CaptureEngine`.
@Observable
@MainActor
final class CameraController {
    enum Status: Equatable { case idle, running, unauthorized, unavailable, failed }

    private(set) var status: Status = .idle
    /// Objects found in the latest analysed frame (empty when nothing stands out).
    private(set) var detections: [DetectedObject] = []
    /// Pixel size of the analysed (portrait) frames, used to place boxes on the preview.
    private(set) var frameSize: CGSize = .zero
    /// The active lens. Without a camera (Simulator, previews) the defaults keep the rail drawn.
    private(set) var capabilities = CameraCapabilities()
    /// Current display zoom (1 = wide lens).
    private(set) var zoom: CGFloat = 1

    let engine = CaptureEngine()
    private let detector: any ObjectDetecting

    var session: AVCaptureSession { engine.session }
    var isRunning: Bool { status == .running }

    init(detector: any ObjectDetecting = VisionObjectDetector()) {
        self.detector = detector
    }

    func start() async {
        guard status != .running else { return }
        guard !Self.isRunningForPreviews, CaptureEngine.isAvailable else {
            status = .unavailable
            return
        }
        guard await Self.requestAccess() else {
            status = .unauthorized
            return
        }

        let detector = detector
        engine.onFrame = { [weak self] buffer in
            // Runs on the frame queue; `nil` means the frame was skipped (throttling).
            guard let objects = detector.detect(in: buffer) else { return }
            let size = CGSize(width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer))
            Task { @MainActor [weak self] in
                self?.frameSize = size
                self?.detections = objects
            }
        }

        do {
            capabilities = try await engine.start()
            zoom = 1
            status = .running
        } catch {
            Log.scan.error("Camera start failed: \(error.localizedDescription)")
            status = .failed
        }
    }

    func stop() {
        engine.setTorch(false)
        engine.stop()
        detections = []
        if status == .running { status = .idle }
    }

    func setTorch(_ on: Bool) { engine.setTorch(on) }

    /// Sets the display zoom, clamped to what the lens allows. `animated` ramps smoothly (rail taps);
    /// pinching sets it directly.
    func setZoom(_ value: CGFloat, animated: Bool = true) {
        let clamped = min(max(value, capabilities.minZoom), capabilities.maxZoom)
        zoom = clamped
        guard status == .running else { return }
        engine.setZoom(clamped * capabilities.zoomMultiplier, animated: animated)
    }

    /// Switches between the back and front cameras.
    func flip() async {
        guard status == .running else { return }
        let next: AVCaptureDevice.Position = capabilities.position == .back ? .front : .back
        do {
            capabilities = try await engine.switchCamera(to: next)
            zoom = 1
            detections = []
        } catch {
            Log.scan.error("Camera flip failed: \(error.localizedDescription)")
        }
    }

    /// JPEG/HEIC data of a full-resolution still, or `nil` if the camera isn't running.
    func capturePhoto(flash: Bool = false) async -> Data? {
        guard status == .running else { return nil }
        do {
            return try await engine.capturePhoto(flash: flash)
        } catch {
            Log.scan.error("Photo capture failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    private static var isRunningForPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

/// Owns the `AVCaptureSession`. Following Apple's pattern, all session work
/// runs on a private serial queue and frames arrive on a second one. Every
/// mutable property is touched only on those queues, hence `@unchecked Sendable`.
final class CaptureEngine: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()

    /// Called on the frame queue with each portrait-oriented video frame.
    /// Set it before `start()`.
    var onFrame: (@Sendable (CVPixelBuffer) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.culture.camera.session")
    private let frameQueue = DispatchQueue(label: "com.culture.camera.frames", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var device: AVCaptureDevice?
    private var input: AVCaptureDeviceInput?
    private var isConfigured = false
    private var capabilities = CameraCapabilities()
    private var inFlightCaptures: [Int64: PhotoCaptureProcessor] = [:]

    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    func start() async throws -> CameraCapabilities {
        try await onSessionQueue { [self] in
            if !isConfigured { try configure() }
            if !session.isRunning { session.startRunning() }
            return capabilities
        }
    }

    func switchCamera(to position: AVCaptureDevice.Position) async throws -> CameraCapabilities {
        try await onSessionQueue { [self] in
            session.beginConfiguration()
            defer { session.commitConfiguration() }
            try attachDevice(at: position)
            return capabilities
        }
    }

    /// `factor` is the raw `videoZoomFactor`.
    func setZoom(_ factor: CGFloat, animated: Bool) {
        sessionQueue.async { [self] in
            guard let device else { return }
            let clamped = min(max(factor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            do {
                try device.lockForConfiguration()
                if animated {
                    device.ramp(toVideoZoomFactor: clamped, withRate: 12)
                } else {
                    device.cancelVideoZoomRamp()
                    device.videoZoomFactor = clamped
                }
                device.unlockForConfiguration()
            } catch {
                Log.scan.error("Zoom failed: \(error.localizedDescription)")
            }
        }
    }

    private func onSessionQueue<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            sessionQueue.async {
                do { continuation.resume(returning: try work()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func setTorch(_ on: Bool) {
        sessionQueue.async { [self] in
            guard let device, device.hasTorch, device.isTorchAvailable else { return }
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {
                Log.scan.error("Torch failed: \(error.localizedDescription)")
            }
        }
    }

    func capturePhoto(flash: Bool = false) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            sessionQueue.async { [self] in
                guard session.isRunning else {
                    continuation.resume(throwing: CameraError.captureFailed)
                    return
                }
                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .balanced
                if flash, photoOutput.supportedFlashModes.contains(.on) { settings.flashMode = .on }
                let id = settings.uniqueID
                let processor = PhotoCaptureProcessor { [weak self] result in
                    self?.sessionQueue.async { self?.inFlightCaptures[id] = nil }
                    continuation.resume(with: result)
                }
                inFlightCaptures[id] = processor
                photoOutput.capturePhoto(with: settings, delegate: processor)
            }
        }
    }

    /// Session queue only.
    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo
        guard session.canAddOutput(photoOutput) else { throw CameraError.configurationFailed }
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .balanced

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        ]
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
        guard session.canAddOutput(videoOutput) else { throw CameraError.configurationFailed }
        session.addOutput(videoOutput)

        try attachDevice(at: .back)
        isConfigured = true
    }

    /// Session queue only, inside a configuration block. Swaps the input to the
    /// best camera at `position` and records what it can do.
    private func attachDevice(at position: AVCaptureDevice.Position) throws {
        guard let device = Self.bestDevice(at: position) else { throw CameraError.unavailable }
        let newInput = try AVCaptureDeviceInput(device: device)
        if let input { session.removeInput(input) }
        guard session.canAddInput(newInput) else {
            if let input { session.addInput(input) }
            throw CameraError.configurationFailed
        }
        session.addInput(newInput)

        // Portrait frames, so Vision's coordinates match what the user sees.
        // Connections are rebuilt with the new input, so set this every time.
        for connection in [videoOutput.connection(with: .video), photoOutput.connection(with: .video)] {
            if let connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }

        // On virtual devices with an ultra-wide, factor 1 is the ultra-wide, so 1× (wide) is the first switch-over.
        let hasUltraWide = device.constituentDevices.contains { $0.deviceType == .builtInUltraWideCamera }
        let multiplier = hasUltraWide ? CGFloat(device.virtualDeviceSwitchOverVideoZoomFactors.first?.doubleValue ?? 2) : 1

        try device.lockForConfiguration()
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        device.videoZoomFactor = min(max(multiplier, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        device.unlockForConfiguration()

        capabilities = CameraCapabilities(
            position: position,
            zoomMultiplier: multiplier,
            minZoom: device.minAvailableVideoZoomFactor / multiplier,
            maxZoom: min(device.maxAvailableVideoZoomFactor / multiplier, 10),
            hasFlash: photoOutput.supportedFlashModes.contains(.on)
        )
        self.device = device
        input = newInput
    }

    /// Back: the multi-lens camera when there is one (for 0.5× and 2×), else the wide lens.
    private static func bestDevice(at position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            : [.builtInWideAngleCamera]
        return types.lazy.compactMap { AVCaptureDevice.default($0, for: .video, position: position) }.first
    }
}

extension CaptureEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(buffer)
    }
}

/// Keeps a photo capture's delegate alive until AVFoundation calls back.
private final class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (Result<Data, Error>) -> Void

    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            completion(.failure(error))
        } else if let data = photo.fileDataRepresentation() {
            completion(.success(data))
        } else {
            completion(.failure(CameraError.captureFailed))
        }
    }
}
