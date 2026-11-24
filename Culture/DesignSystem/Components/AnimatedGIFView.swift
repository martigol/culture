//
//  AnimatedGIFView.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import ImageIO
import SwiftUI

/// Plays a bundled animated GIF, looping, filling its frame.
///
/// Frames are streamed by ImageIO (`CGAnimateImageAtURLWithBlock`), one at a
/// time, so even long GIFs never sit fully decoded in memory. Playback stops
/// when the view disappears or `isPlaying` is false; under Reduce Motion only
/// the first frame is shown.
struct AnimatedGIFView: View {
    let url: URL?
    var isPlaying = true

    @State private var frame: CGImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color.clear
            .overlay {
                if let frame {
                    Image(decorative: frame, scale: 1)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .background(Color.black)
            .accessibilityHidden(true)
            .task(id: TaskKey(url: url, playing: isPlaying && !reduceMotion)) { await run() }
    }

    private struct TaskKey: Equatable {
        let url: URL?
        let playing: Bool
    }

    private func run() async {
        guard let url else { return }
        if frame == nil { frame = Self.firstFrame(at: url) }
        guard isPlaying, !reduceMotion else { return }

        let flag = StopFlag()
        let options = [kCGImageAnimationLoopCount: kCFNumberPositiveInfinity] as CFDictionary
        // The block runs on the main queue for each frame, at the GIF's own timing.
        CGAnimateImageAtURLWithBlock(url as CFURL, options) { _, image, stop in
            if flag.isStopped {
                stop.pointee = true
                return
            }
            MainActor.assumeIsolated { frame = image }
        }
        // Keep playing until this task is cancelled (view gone or paused).
        try? await Task.sleep(for: .seconds(60 * 60 * 24))
        flag.stop()
    }

    private static func firstFrame(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

/// Tells the ImageIO animation block to stop (read on the main queue).
private final class StopFlag: @unchecked Sendable {
    private(set) var isStopped = false
    func stop() { isStopped = true }
}

#Preview {
    AnimatedGIFView(url: SceneBackdrop.divine.url)
        .frame(width: 300, height: 380)
        .clipShape(RoundedRectangle(cornerRadius: 16))
}
