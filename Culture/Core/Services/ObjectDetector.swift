//
//  ObjectDetector.swift
//  Culture
//
//  Created by Mario Martinelli on 23/11/2026.
//

import CoreGraphics
import CoreML
import CoreVideo
import Vision

/// Something found in a camera frame.
struct DetectedObject: Identifiable, Hashable, Sendable {
    /// Rank in the frame (0 = most confident). Stable across frames, so the
    /// boxes glide to new positions instead of flickering.
    let id: Int
    /// Raw classifier identifier, e.g. "sculpture" or "musical_instrument".
    let label: String
    let confidence: Float
    /// Normalised Vision rect (0…1, origin bottom-left) in the portrait frame.
    let boundingBox: CGRect

    var displayLabel: String { Self.displayName(for: label) }
    var percent: String { "\(Int((confidence * 100).rounded()))%" }

    /// "musical_instrument" → "Musical instrument".
    static func displayName(for label: String) -> String {
        let words = label.replacingOccurrences(of: "_", with: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}

protocol ObjectDetecting: AnyObject, Sendable {
    /// Called on the camera's frame queue for every frame.
    /// Returns `nil` when the frame is skipped (throttling).
    func detect(in pixelBuffer: CVPixelBuffer) -> [DetectedObject]?
}

/// Live object detection with Vision, entirely on device.
///
/// - **With a model:** add an object-detection Core ML model to the target and
///   name it `ObjectDetector.mlmodel` (for example Apple's YOLOv3 from
///   developer.apple.com/machine-learning/models, or your own Create ML
///   Object Detector). You get a real label and box per object.
/// - **Without a model (default):** objectness saliency finds the objects in
///   the frame, and Vision's built-in classifier (~1,300 categories) labels
///   each region.
final class VisionObjectDetector: ObjectDetecting, @unchecked Sendable {
    /// Seconds between analysed frames (about 4 fps keeps the phone cool).
    var minimumInterval: TimeInterval = 0.25
    var maxObjects = 3
    var minimumConfidence: Float = 0.3

    // Frame queue only.
    private var lastRun = Date.distantPast
    private lazy var model: VNCoreMLModel? = VisionModels.load("ObjectDetector")

    func detect(in pixelBuffer: CVPixelBuffer) -> [DetectedObject]? {
        let now = Date()
        guard now.timeIntervalSince(lastRun) >= minimumInterval else { return nil }
        lastRun = now

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            if let model { return try detectWithModel(model, handler: handler) }
            return try detectWithSaliency(handler: handler)
        } catch {
            Log.scan.error("Detection failed: \(error.localizedDescription)")
            return []
        }
    }

    private func detectWithModel(_ model: VNCoreMLModel, handler: VNImageRequestHandler) throws -> [DetectedObject] {
        let request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill
        try handler.perform([request])

        let found = (request.results as? [VNRecognizedObjectObservation] ?? [])
            .compactMap { observation -> (label: String, confidence: Float, box: CGRect)? in
                guard let top = observation.labels.first, top.confidence >= minimumConfidence else { return nil }
                return (top.identifier, top.confidence, observation.boundingBox)
            }
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxObjects)

        return found.enumerated().map { index, item in
            DetectedObject(id: index, label: item.label, confidence: item.confidence, boundingBox: item.box)
        }
    }

    private func detectWithSaliency(handler: VNImageRequestHandler) throws -> [DetectedObject] {
        let saliency = VNGenerateObjectnessBasedSaliencyImageRequest()
        try handler.perform([saliency])

        let regions = Array(
            (saliency.results?.first?.salientObjects ?? [])
                .filter { $0.boundingBox.width * $0.boundingBox.height > 0.02 }
                .sorted { $0.confidence > $1.confidence }
                .prefix(maxObjects)
        )
        guard !regions.isEmpty else { return [] }

        // One classifier per region, all run in a single pass on the same frame.
        let classifiers = regions.map { region -> VNClassifyImageRequest in
            let request = VNClassifyImageRequest()
            request.regionOfInterest = region.boundingBox
            return request
        }
        try handler.perform(classifiers)

        return zip(regions, classifiers).enumerated().map { index, pair in
            let (region, classifier) = pair
            let best = (classifier.results ?? [])
                .filter { $0.confidence >= minimumConfidence }
                .max { $0.confidence < $1.confidence }
            return DetectedObject(
                id: index,
                label: best?.identifier ?? "object",
                confidence: best?.confidence ?? region.confidence,
                boundingBox: region.boundingBox
            )
        }
    }
}

/// Loads optional, compiled Core ML models bundled with the app.
enum VisionModels {
    /// `name` is the model file name without extension (Xcode compiles
    /// `Name.mlmodel` into `Name.mlmodelc`). Returns `nil` if it isn't bundled.
    static func load(_ name: String) -> VNCoreMLModel? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else { return nil }
        do {
            return try VNCoreMLModel(for: MLModel(contentsOf: url, configuration: MLModelConfiguration()))
        } catch {
            Log.scan.error("Couldn't load model \(name, privacy: .public): \(error.localizedDescription)")
            return nil
        }
    }
}
