//
//  VisionScanService.swift
//  Culture
//
//  Created by Mario Martinelli on 23/11/2026.
//

import ImageIO
import UIKit
import Vision

enum ScanError: LocalizedError {
    case noImage
    /// Nothing in the catalogue matched. `labels` = what Vision thought it saw.
    case noMatch(labels: [String])

    var errorDescription: String? {
        switch self {
        case .noImage: "No photo was captured."
        case .noMatch: "No story matches this object yet."
        }
    }
}

/// Identifies a monument or artifact from a captured photo, on device.
///
/// 1. **Custom model (recommended for production):** add a Create ML *Image
///    Classifier* named `LandmarkClassifier.mlmodel` whose class labels are
///    story IDs (`parthenon`, `zeus`, `agamemnon`…). Its top prediction maps
///    straight to a story.
/// 2. **Fallback (works out of the box):** Vision's built-in classifier labels
///    the photo ("statue", "ruins", "mask"…) and `RecognitionCatalog` scores
///    those labels against each story's keywords. It can tell a mask from a
///    temple, but not one bronze statue from another; that's what step 1 is for.
struct VisionScanService: ScanRecognizing {
    let stories: any StoryProviding
    var catalog = RecognitionCatalog.default
    var minimumModelConfidence: Float = 0.6

    func recognize(imageData: Data?) async throws -> Story {
        guard let imageData, let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            throw ScanError.noImage
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let catalog = catalog
        let threshold = minimumModelConfidence

        let storyID = try await Task.detached(priority: .userInitiated) {
            try Self.identify(cgImage, orientation: orientation, catalog: catalog, threshold: threshold)
        }.value

        guard let story = try await stories.story(id: storyID) else {
            throw ScanError.noMatch(labels: [])
        }
        return story
    }

    private static let landmarkModel = VisionModels.load("LandmarkClassifier")

    private static func identify(_ image: CGImage, orientation: CGImagePropertyOrientation,
                                 catalog: RecognitionCatalog, threshold: Float) throws -> Story.ID {
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation)

        if let landmarkModel {
            let request = VNCoreMLRequest(model: landmarkModel)
            request.imageCropAndScaleOption = .centerCrop
            try handler.perform([request])
            if let top = (request.results as? [VNClassificationObservation])?.first, top.confidence >= threshold {
                return top.identifier
            }
        }

        let request = VNClassifyImageRequest()
        try handler.perform([request])
        let labels = (request.results ?? [])
            .filter { $0.confidence > 0.05 }
            .sorted { $0.confidence > $1.confidence }
            .map { (label: $0.identifier, confidence: $0.confidence) }

        #if DEBUG
        // Point the camera at real objects and use these to tune `RecognitionCatalog`.
        let summary = labels.prefix(8).map { "\($0.label) \(Int($0.confidence * 100))%" }.joined(separator: ", ")
        Log.scan.debug("Vision labels: \(summary, privacy: .public)")
        #endif

        guard let id = catalog.bestMatch(for: labels) else {
            throw ScanError.noMatch(labels: labels.prefix(3).map { DetectedObject.displayName(for: $0.label) })
        }
        return id
    }
}

/// Maps Vision's generic labels to stories. Keywords are lowercase Vision
/// identifiers; weights say how telling a label is for that story.
struct RecognitionCatalog: Sendable {
    struct Entry: Sendable {
        let storyID: Story.ID
        let keywords: [String: Double]
    }

    var entries: [Entry]
    /// Below this, the scan reports "no match" rather than guessing.
    var minimumScore = 0.12

    func bestMatch(for labels: [(label: String, confidence: Float)]) -> Story.ID? {
        var best: (id: Story.ID, score: Double)?
        for entry in entries {
            var score = 0.0
            for (label, confidence) in labels {
                if let weight = entry.keywords[label.lowercased()] { score += weight * Double(confidence) }
            }
            if score > (best?.score ?? 0) { best = (entry.storyID, score) }
        }
        guard let best, best.score >= minimumScore else { return nil }
        return best.id
    }

    static let `default` = RecognitionCatalog(entries: [
        Entry(storyID: "parthenon", keywords: ["temple": 1.0, "acropolis": 1.0, "column": 0.9, "monument": 0.5, "ruins": 0.5, "architecture": 0.3]),
        Entry(storyID: "sounion", keywords: ["cliff": 0.8, "temple": 0.8, "column": 0.7, "coast": 0.6, "sea": 0.6, "ocean": 0.5, "ruins": 0.4]),
        Entry(storyID: "delphi", keywords: ["ruins": 0.8, "mountain": 0.6, "column": 0.5, "temple": 0.5, "hill": 0.4]),
        Entry(storyID: "olympia", keywords: ["ruins": 0.7, "stadium": 0.6, "column": 0.5, "archaeology": 0.5]),
        Entry(storyID: "knossos", keywords: ["fresco": 1.0, "palace": 0.9, "mural": 0.8, "painting": 0.4, "ruins": 0.5, "wall": 0.3]),
        Entry(storyID: "mycenae", keywords: ["gate": 1.0, "lion": 0.9, "arch": 0.7, "archway": 0.7, "wall": 0.6, "stone": 0.5, "ruins": 0.4]),
        Entry(storyID: "epidaurus", keywords: ["theater": 1.0, "amphitheater": 1.0, "auditorium": 0.6, "stadium": 0.6, "stairs": 0.5, "steps": 0.5]),
        Entry(storyID: "agamemnon", keywords: ["mask": 1.0, "gold": 0.9, "jewelry": 0.5, "artifact": 0.4, "face": 0.4]),
        Entry(storyID: "nike", keywords: ["wing": 0.9, "angel": 0.7, "sculpture": 0.8, "statue": 0.7, "marble": 0.6]),
        Entry(storyID: "medusa", keywords: ["relief": 0.8, "face": 0.6, "sculpture": 0.6, "marble": 0.5, "mask": 0.3]),
        Entry(storyID: "zeus", keywords: ["statue": 0.8, "sculpture": 0.8, "bronze": 0.7, "figurine": 0.4]),
        Entry(storyID: "charioteer", keywords: ["statue": 0.7, "sculpture": 0.7, "bronze": 0.6]),
    ])
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
