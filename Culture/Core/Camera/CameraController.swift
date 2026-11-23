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

/// UI-facing camera state for the Scan screen: permission, live detections,
/// torch and still capture. All AVFoundation work lives in `CaptureEngine`.
@Observable
@MainActor
final class CameraController {
    enum Status: Equatable { case idle, running, unauthorized, unavailable, failed }

    private(set) var status: Status = .idle
    /// Objects found in the latest analysed frame (empty when nothing stands out).
    private(set) var detections: [DetectedObject] = []
    /// Pixel size of the analysed (portrait) frames, used to place boxes on the preview.
    private(set) var frameSize: CGSize = .zero

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
            try await engine.start()
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

    /// JPEG/HEIC data of a full-resolution still, or `nil` if the camera isn't running.
    func capturePhoto() async -> Data? {
        guard status == .running else { return nil }
        do {
            return try await engine.capturePhoto()
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
    private var isConfigured = false
    private var inFlightCaptures: [Int64: PhotoCaptureProcessor] = [:]

    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [self] in
                do {
                    if !isConfigured { try configure() }
                    if !session.isRunning { session.startRunning() }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
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

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            sessionQueue.async { [self] in
                guard session.isRunning else {
                    continuation.resume(throwing: CameraError.captureFailed)
                    return
                }
                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .balanced
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
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.unavailable
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.configurationFailed }
        session.addInput(input)

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

        // Portrait frames, so Vision's coordinates match what the user sees.
        for connection in [videoOutput.connection(with: .video), photoOutput.connection(with: .video)] {
            if let connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }

        if device.isFocusModeSupported(.continuousAutoFocus) {
            try device.lockForConfiguration()
            device.focusMode = .continuousAutoFocus
            device.unlockForConfiguration()
        }

        self.device = device
        isConfigured = true
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
