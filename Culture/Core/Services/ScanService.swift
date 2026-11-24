import Foundation

/// Recognises a monument / artifact from a captured frame.
/// TODO(scan-team): Implement with Vision / CoreML or a server endpoint.
protocol ScanRecognizing: Sendable {
    func recognize(imageData: Data?) async throws -> Story
}

struct MockScanService: ScanRecognizing {
    func recognize(imageData: Data?) async throws -> Story {
        try await Task.sleep(for: .seconds(1.6))
        return MockData.stories.randomElement()!
    }
}
