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

/// Which storylines have been watched to the end (remembered across launches),
/// and what to watch next.
enum StorylineProgress {
    private static let key = "watchedStorylines"

    static var watched: Set<Story.ID> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    static func markWatched(_ id: Story.ID) {
        var all = watched
        all.insert(id)
        UserDefaults.standard.set(Array(all), forKey: key)
    }

    static var total: Int { Storyline.storyIDs.count }

    /// The next unwatched storyline after `id` (wrapping round), else simply the next one.
    static func next(after id: Story.ID) -> Story? {
        let ids = Storyline.storyIDs
        guard let start = ids.firstIndex(of: id), ids.count > 1 else { return ids.first.flatMap(MockData.story) }
        let rotated = Array(ids[(start + 1)...] + ids[..<start])
        let pick = rotated.first { !watched.contains($0) } ?? rotated.first
        return pick.flatMap(MockData.story)
    }
}

/// The storyline, full screen: animated scenes with the tale told over them,
/// advancing on their own like stories. Tap right/left to skip, hold to pause,
/// swipe down to close. Sound on reads each scene aloud and moves on when done.
///
/// Interactive: at its turning point the story stops and asks what you think
/// happens — answer, see the reveal, carry on. At the end it counts you down
/// into the next myth ("Up next"), so one story leads to another.
struct StorylinePlayer: View {
    /// "Read the full story" at the end (for whichever story is showing then).
    var onFinish: (Story) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var story: Story
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

    // Interaction
    @State private var asking: SceneQuestion?
    @State private var chosen: Int?
    @State private var answeredScenes: Set<Int> = []
    @State private var correctAnswers = 0

    // Up next
    @State private var upNext: Story?
    @State private var countdown: Double = 0
    @State private var autoPlayNext = true

    private static let upNextDelay = 8.0

    init(story: Story, onFinish: @escaping (Story) -> Void) {
        self.onFinish = onFinish
        _story = State(initialValue: story)
    }

    private var scenes: [StoryScene] { Storyline.scenes(for: story) }
    private var scene: StoryScene { scenes[min(index, scenes.count - 1)] }
    private var questionCount: Int { scenes.filter { $0.question != nil }.count }
    private var isPaused: Bool { isHolding || isFinished || asking != nil }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Backdrop: the scene's GIF, crossfading between scenes, slowly pushing in.
            AnimatedGIFView(url: scene.backdrop.url, isPlaying: !isFinished)
                .storylineTreatment()
                .scaleEffect(kenBurns ? 1.12 : 1.0)
                .tiltParallax(magnitude: 14)
                .blur(radius: asking == nil ? 0 : 6)
                .id("\(story.id)-\(scene.id)")
                .transition(.opacity)
                .ignoresSafeArea()

            LinearGradient(stops: [
                .init(color: .black.opacity(0.55), location: 0),
                .init(color: .clear, location: 0.22),
                .init(color: .clear, location: 0.45),
                .init(color: .black.opacity(asking == nil ? 0.9 : 0.95), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                topBar
                Spacer()
                if isFinished {
                    endCard
                } else if let asking {
                    questionCard(asking)
                } else {
                    caption
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.xl)
        }
        .offset(y: dragOffset)
        .contentShape(Rectangle())
        .gesture(isFinished || asking != nil ? nil : pressGesture)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .sensoryFeedback(.selection, trigger: index)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .task(id: PlayKey(story: story.id, index: index, replays: replays)) { await play(scene) }
        .task(id: isFinished) { await countDownToNext() }
        .onChange(of: isHolding) { _, holding in
            guard soundOn else { return }
            holding ? narrator.pause() : narrator.play()
        }
        .onChange(of: soundOn) { _, on in
            if on { speak(scene) } else { narrator.stop() }
        }
        .onChange(of: narrator.isPlaying) { _, playing in
            // With sound on, a scene ends when its narration does.
            if soundOn, !playing, !isHolding, asking == nil, narrator.progress >= 0.98 { advance() }
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
        if asking != nil { return 1 }
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

            if scene.question != nil, !answeredScenes.contains(scene.id) {
                Label("Your turn next", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(.top, Spacing.xxs)
            }
        }
        .id("\(story.id)-\(scene.id)")
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

    // MARK: Question

    /// The story waits: pick what you think happens, see the reveal, carry on.
    private func questionCard(_ question: SceneQuestion) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label("WHAT HAPPENS NEXT?", systemImage: "questionmark.bubble")
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(Palette.inkSecondary)

            Text(question.prompt)
                .textStyle(.title)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: Spacing.xs) {
                ForEach(question.options.indices, id: \.self) { i in
                    optionButton(question, i)
                }
            }

            if let chosen {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(chosen == question.answer ? "You guessed it." : "Not quite.")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(question.reveal)
                        .textStyle(.body)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Continue the story") { continueAfterQuestion() }
                        .buttonStyle(.primary)
                        .padding(.top, Spacing.xxs)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(Spacing.md)
        .glassCard(cornerRadius: Radius.cardInner)
        .transition(.scale(scale: 0.94).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: chosen)
        .sensoryFeedback(trigger: chosen) { _, new in
            guard let new else { return nil }
            return new == question.answer ? .success : .warning
        }
    }

    private func optionButton(_ question: SceneQuestion, _ i: Int) -> some View {
        let isAnswer = i == question.answer
        let isChosen = i == chosen
        let revealed = chosen != nil

        return Button {
            guard chosen == nil else { return }
            chosen = i
            if isAnswer { correctAnswers += 1 }
        } label: {
            HStack(spacing: Spacing.sm) {
                Text(question.options[i])
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(revealed && isAnswer ? Palette.onAccent : Palette.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if revealed && (isAnswer || isChosen) {
                    Image(systemName: isAnswer ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(isAnswer ? Palette.onAccent : Palette.inkSecondary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .background { if revealed && isAnswer { Capsule().fill(Palette.accent) } }
            .glassSurface(in: Capsule(), tint: revealed && isAnswer ? Palette.accent : nil)
            .opacity(revealed && !isAnswer && !isChosen ? 0.5 : 1)
        }
        .buttonStyle(.pressable)
        .disabled(revealed)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    private func continueAfterQuestion() {
        answeredScenes.insert(scene.id)
        withAnimation(Motion.smooth) {
            asking = nil
            chosen = nil
        }
        advance()
    }

    // MARK: End & up next

    private var endCard: some View {
        let watched = StorylineProgress.watched.count
        let total = max(StorylineProgress.total, 1)

        return VStack(alignment: .leading, spacing: Spacing.md) {
            Text("THE END")
                .font(.caption.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(Palette.inkSecondary)
            Text(story.title)
                .textStyle(.display)
                .foregroundStyle(Palette.ink)

            // Progress through every myth, and how the guesses went.
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text("You've explored \(watched) of \(total) myths")
                    Spacer()
                    if questionCount > 0 {
                        Text("\(correctAnswers)/\(questionCount) guessed")
                            .monospacedDigit()
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkSecondary)
                GeometryReader { geo in
                    Capsule().fill(Palette.ink.opacity(0.15))
                        .overlay(alignment: .leading) {
                            Capsule().fill(Palette.ink)
                                .frame(width: geo.size.width * Double(watched) / Double(total))
                        }
                }
                .frame(height: 4)
            }

            if let upNext { upNextCard(upNext) }

            HStack(spacing: Spacing.sm) {
                Button("Read the full story") {
                    autoPlayNext = false
                    onFinish(story)
                    dismiss()
                }
                .buttonStyle(.primary)
                Button("Watch again") { restart() }
                    .buttonStyle(.secondary)
            }
            .padding(.top, Spacing.xxs)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// The next myth, counting down to start by itself (tap to start now, or stop).
    private func upNextCard(_ next: Story) -> some View {
        HStack(spacing: Spacing.md) {
            ArtworkView(artwork: next.artwork, motion: false)
                .frame(width: 64, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(autoPlayNext ? "UP NEXT IN \(Int(ceil(countdown)))" : "UP NEXT")
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
                    .contentTransition(.numericText(countsDown: true))
                Text(next.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(next.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button { load(next) } label: {
                ZStack {
                    Circle().stroke(Palette.ink.opacity(0.2), lineWidth: 3)
                    if autoPlayNext {
                        Circle()
                            .trim(from: 0, to: 1 - countdown / Self.upNextDelay)
                            .stroke(Palette.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
                .frame(width: 48, height: 48)
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Play \(next.title)")
        }
        .padding(Spacing.sm)
        .glassCard(cornerRadius: Radius.cardInner, glow: next.artwork)
        .overlay(alignment: .topTrailing) {
            if autoPlayNext {
                Button { autoPlayNext = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(width: 26, height: 26)
                        .glassSurface(in: Circle())
                }
                .offset(x: 6, y: -6)
                .accessibilityLabel("Don't play next")
            }
        }
    }

    private func countDownToNext() async {
        guard isFinished else { return }
        StorylineProgress.markWatched(story.id)
        upNext = StorylineProgress.next(after: story.id)
        countdown = Self.upNextDelay
        guard upNext != nil else { return }
        while countdown > 0, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
            guard autoPlayNext else { return }
            withAnimation(.linear(duration: 0.1)) { countdown = max(countdown - 0.1, 0) }
        }
        guard !Task.isCancelled, autoPlayNext, let upNext else { return }
        load(upNext)
    }

    /// Switches to another story's storyline without leaving the player.
    private func load(_ next: Story) {
        narrator.stop()
        withAnimation(Motion.smooth) {
            story = next
            index = 0
            isFinished = false
            asking = nil
            chosen = nil
        }
        answeredScenes = []
        correctAnswers = 0
        autoPlayNext = true
        upNext = nil
        replays += 1
    }

    // MARK: Playback

    private struct PlayKey: Equatable {
        let story: Story.ID
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

    /// Next scene — unless this scene asks a question that hasn't been answered yet.
    private func advance() {
        narrator.stop()
        if let question = scene.question, !answeredScenes.contains(scene.id) {
            revealedWords = scene.text.split(separator: " ").count
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { asking = question }
            return
        }
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
        load(story)
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

#Preview("Myth with a question") {
    StorylinePlayer(story: MockData.story("birth-of-zeus")!) { _ in }
        .previewEnvironment()
}

#Preview("Player") {
    let story = MockData.story("knossos")!
    return StorylinePlayer(story: story) { _ in }
        .previewEnvironment()
}
