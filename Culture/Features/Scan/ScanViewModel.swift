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

    func capture(using scanner: any ScanRecognizing) async {
        guard phase == .aiming || phase == .failed else { return }
        phase = .recognizing
        do {
            // TODO(scan-team): pass the captured frame data here.
            let story = try await scanner.recognize(imageData: nil)
            phase = .recognized(story)
            Log.scan.info("Recognition succeeded")
        } catch is CancellationError {
            phase = .aiming
        } catch {
            Log.scan.error("Recognition failed: \(error.localizedDescription)")
            phase = .failed
        }
    }

    func reset() { phase = .aiming }
}
