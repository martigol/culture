import SwiftUI
import Observation

@Observable
@MainActor
final class ScanViewModel {
    enum Phase: Equatable {
        case aiming
        case recognizing
        case recognized(Story)
        case failed
    }

    var phase: Phase = .aiming
    var isFlashOn = false
    /// What Vision saw when nothing matched, e.g. "Looks like: Sculpture, Marble".
    var failureHint: String?

    /// Takes a still from `camera` (if running) and identifies it.
    /// Without a camera (Simulator, previews) the scanner gets `nil` data.
    func capture(using scanner: any ScanRecognizing, camera: CameraController?) async {
        guard phase == .aiming || phase == .failed else { return }
        phase = .recognizing
        failureHint = nil
        do {
            let photo = await camera?.capturePhoto()
            let story = try await scanner.recognize(imageData: photo)
            phase = .recognized(story)
            Log.scan.info("Recognition succeeded")
        } catch is CancellationError {
            phase = .aiming
        } catch ScanError.noMatch(let labels) {
            failureHint = labels.isEmpty ? nil : "Looks like: \(labels.joined(separator: ", "))"
            phase = .failed
        } catch {
            Log.scan.error("Recognition failed: \(error.localizedDescription)")
            phase = .failed
        }
    }

    func reset() {
        phase = .aiming
        failureHint = nil
    }
}
