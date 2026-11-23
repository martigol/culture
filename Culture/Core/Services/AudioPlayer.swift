import Foundation
import Observation

/// Simulated narration player so the UI is fully interactive.
/// TODO(audio-team): Back with AVPlayer + MPNowPlayingInfoCenter.
@Observable
@MainActor
final class AudioPlayer {
    private(set) var isPlaying = false
    var elapsed: Double = 0
    private(set) var duration: Double = 1
    private var timer: Timer?

    var progress: Double { duration > 0 ? elapsed / duration : 0 }

    func load(duration seconds: Int) {
        stop()
        duration = Double(max(seconds, 1))
        elapsed = 0
    }

    func toggle() { isPlaying ? pause() : play() }

    func play() {
        guard !isPlaying else { return }
        if elapsed >= duration { elapsed = 0 }
        isPlaying = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
    }

    func stop() { pause(); elapsed = 0 }

    func skip(by seconds: Double) {
        elapsed = min(max(elapsed + seconds, 0), duration)
    }

    private func tick() {
        elapsed += 0.5
        if elapsed >= duration { elapsed = duration; pause() }
    }

    static func format(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
