//
//  StorylinePlayer.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import SwiftUI

/// Story-page card that opens the storyline: the first scene playing, the
/// scene count and a play button.
struct StorylineCard: View {
    let story: Story
    let scenes: [StoryScene]
    var isPlaying = true
    var onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            ZStack(alignment: .bottomLeading) {
                AnimatedGIFView(url: scenes.first?.backdrop.url, isPlaying: isPlaying)
                    .storylineTreatment()
                    .overlay(
                        LinearGradient(colors: [.clear, .black.opacity(0.25), .black.opacity(0.85)],
                                       startPoint: .top, endPoint: .bottom)
                    )

                Text("STORYLINE")
                    .font(.caption2.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                HStack(alignment: .bottom, spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("Watch the story come alive")
                            .textStyle(.title)
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                        Text("\(scenes.count) scenes · about \(Storyline.minutes(for: scenes)) min")
                            .textStyle(.label)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.onAccent)
                        .frame(width: 52, height: 52)
                        .background(Palette.accent, in: Circle())
                }
                .padding(Spacing.md)
            }
            .aspectRatio(4 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 0.75)
            )
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Storyline: \(story.title), \(scenes.count) scenes")
        .accessibilityHint("Plays the story as animated scenes")
        .accessibilityAddTraits(.isButton)
    }
}

/// The storyline, full screen: animated scenes with the tale told over them,
/// advancing on their own like stories. Tap right/left to skip, hold to pause,
/// swipe down to close. Sound on reads each scene aloud and moves on when done.
struct StorylinePlayer: View {
    let story: Story
    let scenes: [StoryScene]
    /// "Read the full story" at the end.
    var onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0
    @State private var progress: Double = 0
    @State private var isHolding = false
    @State private var isFinished = false
    @State private var soundOn = false
    @State private var narrator = StoryNarrator()
    @State private var revealedWords = 0
    @State private var kenBurns = false
    @State private var dragOffset: CGFloat = 0
    @State private var pressStart: Date?
    /// Bumped to replay the current scene from the start.
    @State private var replays = 0
    @State private var width: CGFloat = 390

    private var scene: StoryScene { scenes[min(index, scenes.count - 1)] }
    private var isPaused: Bool { isHolding || isFinished }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Backdrop: the scene's GIF, crossfading between scenes, slowly pushing in.
            AnimatedGIFView(url: scene.backdrop.url, isPlaying: !isFinished)
                .storylineTreatment()
                .scaleEffect(kenBurns ? 1.12 : 1.0)
                .tiltParallax(magnitude: 14)
                .id(scene.id)
                .transition(.opacity)
                .ignoresSafeArea()

            LinearGradient(stops: [
                .init(color: .black.opacity(0.55), location: 0),
                .init(color: .clear, location: 0.22),
                .init(color: .clear, location: 0.45),
                .init(color: .black.opacity(0.9), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                topBar
                Spacer()
                if isFinished { endCard } else { caption }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.xl)
        }
        .offset(y: dragOffset)
        .contentShape(Rectangle())
        .gesture(isFinished ? nil : pressGesture)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .sensoryFeedback(.selection, trigger: index)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .task(id: PlayKey(index: index, replays: replays)) { await play(scene) }
        .onChange(of: isHolding) { _, holding in
            guard soundOn else { return }
            holding ? narrator.pause() : narrator.play()
        }
        .onChange(of: soundOn) { _, on in
            if on { speak(scene) } else { narrator.stop() }
        }
        .onChange(of: narrator.isPlaying) { _, playing in
            // With sound on, a scene ends when its narration does.
            if soundOn, !playing, !isHolding, narrator.progress >= 0.98 { advance() }
        }
        .onDisappear { narrator.stop() }
    }

    // MARK: Chrome

    private var topBar: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: 4) {
                ForEach(scenes.indices, id: \.self) { i in
                    GeometryReader { geo in
                        Capsule().fill(Palette.ink.opacity(0.25))
                            .overlay(alignment: .leading) {
                                Capsule().fill(Palette.ink)
                                    .frame(width: geo.size.width * fill(for: i))
                            }
                    }
                    .frame(height: 2.5)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Scene \(index + 1) of \(scenes.count)")

            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(story.title)
                        .textStyle(.callout)
                        .foregroundStyle(Palette.ink)
                    Text(story.region)
                        .textStyle(.label)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Spacer()
                CircleIconButton(systemName: soundOn ? "speaker.wave.2.fill" : "speaker.slash",
                                 label: soundOn ? "Turn narration off" : "Read scenes aloud") {
                    soundOn.toggle()
                }
                CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
            }
            .foregroundStyle(Palette.ink)
        }
        .padding(.top, Spacing.xs)
    }

    private func fill(for i: Int) -> Double {
        if isFinished || i < index { return 1 }
        if i > index { return 0 }
        return soundOn ? narrator.progress : progress
    }

    private var caption: some View {
        let words = scene.text.split(separator: " ", omittingEmptySubsequences: true)

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("\(Storyline.numeral(index)) · \(scene.title.uppercased())")
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(Palette.inkSecondary)

            // Words fade in one after another, like a voice telling it.
            Text(revealed(words))
                .textStyle(.lede)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.6), radius: 8)
                .animation(.easeOut(duration: 0.35), value: revealedWords)
                .accessibilityLabel(scene.text)
        }
        .id(scene.id)
        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
    }

    private func revealed(_ words: [Substring]) -> AttributedString {
        var result = AttributedString()
        for (i, word) in words.enumerated() {
            var piece = AttributedString(i == 0 ? String(word) : " " + word)
            piece.foregroundColor = i < revealedWords ? Palette.ink : Palette.ink.opacity(0)
            result += piece
        }
        return result
    }

    private var endCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("THE END")
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(Palette.inkSecondary)
            Text(story.title)
                .textStyle(.display)
                .foregroundStyle(Palette.ink)
            Text(story.subtitle)
                .textStyle(.italic)
                .foregroundStyle(Palette.inkSecondary)
            VStack(spacing: Spacing.sm) {
                Button("Read the full story") {
                    dismiss()
                    onFinish()
                }
                .buttonStyle(.primary)
                Button("Watch again") { restart() }
                    .buttonStyle(.secondary)
            }
            .padding(.top, Spacing.sm)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Playback

    private struct PlayKey: Equatable {
        let index: Int
        let replays: Int
    }

    /// Reveals the scene's words, pushes the camera in, then counts down
    /// (or lets narration set the pace).
    private func play(_ scene: StoryScene) async {
        progress = 0
        revealedWords = 0
        kenBurns = false
        let duration = Self.duration(of: scene)
        if !reduceMotion {
            withAnimation(.linear(duration: duration + 1)) { kenBurns = true }
        }
        if soundOn { speak(scene) }

        let wordCount = scene.text.split(separator: " ").count
        let wordDelay = min(0.09, 1.6 / Double(max(wordCount, 1)))
        let tick = 1.0 / 30
        var elapsed = 0.0

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(tick))
            guard !isPaused else { continue }
            elapsed += tick
            revealedWords = reduceMotion ? wordCount : min(wordCount, Int(elapsed / wordDelay) + 1)
            guard !soundOn else { continue } // narration drives progress
            progress = min(elapsed / duration, 1)
            if progress >= 1 {
                advance()
                return
            }
        }
    }

    private func speak(_ scene: StoryScene) {
        narrator.load(text: scene.text)
        if !isHolding { narrator.play() }
    }

    private func advance() {
        narrator.stop()
        if index + 1 < scenes.count {
            withAnimation(Motion.smooth) { index += 1 }
        } else {
            withAnimation(Motion.smooth) { isFinished = true }
        }
    }

    private func goBack() {
        narrator.stop()
        if index > 0 {
            withAnimation(Motion.smooth) { index -= 1 }
        } else {
            replays += 1 // restart the first scene
        }
    }

    private func restart() {
        narrator.stop()
        withAnimation(Motion.smooth) {
            isFinished = false
            index = 0
        }
        replays += 1
    }

    /// Reading time for the scene: never rushed, never dragging.
    private static func duration(of scene: StoryScene) -> Double {
        let words = Double(scene.text.split(separator: " ").count)
        return min(max(words * 0.36, 5.5), 12)
    }

    // MARK: Gestures

    /// Hold to pause, tap left/right to move between scenes, swipe down to close.
    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if pressStart == nil { pressStart = .now }
                if Date.now.timeIntervalSince(pressStart ?? .now) > 0.18 { isHolding = true }
                dragOffset = max(0, value.translation.height) * 0.6
            }
            .onEnded { value in
                let held = Date.now.timeIntervalSince(pressStart ?? .now)
                pressStart = nil
                isHolding = false
                if value.translation.height > 120 {
                    dismiss()
                    return
                }
                withAnimation(Motion.spring) { dragOffset = 0 }
                let moved = abs(value.translation.width) + abs(value.translation.height)
                guard held < 0.3, moved < 12 else { return }
                value.location.x < width * 0.33 ? goBack() : advance()
            }
    }
}

extension Storyline {
    /// Rough running time in minutes (at least 1).
    static func minutes(for scenes: [StoryScene]) -> Int {
        let words = scenes.reduce(0) { $0 + $1.text.split(separator: " ").count }
        return max(1, Int((Double(words) * 0.36 / 60).rounded()))
    }
}

private extension View {
    /// Brand treatment for storyline GIFs: a warm bone wash and faint engraving,
    /// so they sit with the rest of the imagery.
    func storylineTreatment() -> some View {
        self
            .saturation(0.85)
            .colorMultiply(Palette.imageWarmth)
            .overlay(EngravingTexture(opacity: 0.08).blendMode(.multiply))
    }
}

#Preview("Card") {
    let story = MockData.story("knossos")!
    return StorylineCard(story: story, scenes: Storyline.scenes(for: story)) {}
        .padding(Spacing.screen)
        .frame(maxHeight: .infinity)
        .screenBackground()
        .previewEnvironment()
}

#Preview("Player") {
    let story = MockData.story("knossos")!
    return StorylinePlayer(story: story, scenes: Storyline.scenes(for: story)) {}
        .previewEnvironment()
}
