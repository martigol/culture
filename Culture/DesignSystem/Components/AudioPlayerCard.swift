import SwiftUI

/// Inline narration player: the story read aloud by `StoryNarrator`.
struct AudioPlayerCard: View {
    @Bindable var player: StoryNarrator

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                Button(action: player.toggle) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .regular))
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(Palette.onAccent)
                        .frame(width: 48, height: 48)
                        .background(Palette.accent, in: Circle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(player.isPlaying ? "Pause reading" : "Read the story aloud")
                .sensoryFeedback(.selection, trigger: player.isPlaying)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(player.isPlaying ? "Reading…" : "Listen")
                        .textStyle(.headline).foregroundStyle(Palette.ink)
                        .contentTransition(.opacity)
                    Text("Read aloud · \(StoryNarrator.format(player.duration))")
                        .textStyle(.label).foregroundStyle(Palette.inkTertiary)
                        .lineLimit(1)
                        .fixedSize()
                }
                Spacer()
                HStack(spacing: 0) {
                    Button { player.skip(by: -15) } label: {
                        Image(systemName: "gobackward.15").frame(width: HitTarget.minimum, height: HitTarget.minimum)
                    }
                    .accessibilityLabel("Back 15 seconds")
                    Button { player.skip(by: 15) } label: {
                        Image(systemName: "goforward.15").frame(width: HitTarget.minimum, height: HitTarget.minimum)
                    }
                    .accessibilityLabel("Forward 15 seconds")
                }
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(Palette.inkSecondary)
            }

            VStack(spacing: Spacing.xs) {
                ProgressLine(progress: player.progress)
                HStack {
                    Text(StoryNarrator.format(player.elapsed))
                    Spacer()
                    Text("−" + StoryNarrator.format(player.duration - player.elapsed))
                }
                .textStyle(.label)
                .monospacedDigit()
                .foregroundStyle(Palette.inkTertiary)
            }
        }
        .padding(Spacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 0.75)
        )
    }
}

/// Hairline progress track — quieter than a system slider.
private struct ProgressLine: View {
    let progress: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.hairline).frame(height: 1)
                Rectangle().fill(Palette.ink).frame(width: geo.size.width * progress, height: 1)
                Circle().fill(Palette.ink).frame(width: 7, height: 7)
                    .offset(x: geo.size.width * progress - 3.5)
            }
            .frame(height: 7)
        }
        .frame(height: 7)
        .animation(.linear(duration: 0.5), value: progress)
        .accessibilityElement()
        .accessibilityLabel("Playback progress")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

#Preview {
    let narrator = StoryNarrator()
    narrator.load(MockData.story("sounion")!)
    return AudioPlayerCard(player: narrator)
        .padding(Spacing.screen)
        .frame(maxHeight: .infinity)
        .screenBackground()
        .previewEnvironment()
}
