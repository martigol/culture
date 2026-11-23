import SwiftUI

/// Wide editorial card: engraved plate above, text below.
struct FeaturedStoryCard: View {
    let story: Story
    var imageHeight: CGFloat = 220
    var showsTag = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ArtworkView(artwork: story.artwork)
                .frame(height: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if showsTag { TagPill(text: "For you").padding(Spacing.sm) }
                }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(story.title)
                    .textStyle(.title)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                Text(story.subtitle)
                    .textStyle(.italic)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                StoryMeta(story: story)
                    .padding(.top, Spacing.xxs)
            }
        }
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens story")
    }
}

/// Portrait (3:4) plate with caption — statues and artifacts.
struct PortraitStoryCard: View {
    let story: Story
    var width: CGFloat = 164

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ArtworkView(artwork: story.artwork)
                .frame(width: width, height: width * 4 / 3)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(story.title)
                    .textStyle(.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2, reservesSpace: true)
                StoryMeta(story: story)
            }
        }
        .frame(width: width, alignment: .leading)
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .combine)
    }
}

/// Smaller portrait tile (Related, You might also like).
struct StoryTile: View {
    let story: Story
    var body: some View { PortraitStoryCard(story: story, width: 136) }
}

/// List row: plate, meta, title, subtitle, bookmark.
struct StoryRow: View {
    let story: Story
    var isSaved: Bool
    var onToggleSave: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            ArtworkView(artwork: story.artwork)
                .frame(width: 72, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xs, style: .continuous))

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(story.title)
                    .textStyle(.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                Text(story.subtitle)
                    .textStyle(.italic)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                StoryMeta(story: story)
                    .padding(.top, Spacing.xxs)
            }
            Spacer(minLength: 0)

            Button(action: onToggleSave) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .light))
                    .foregroundStyle(isSaved ? Palette.ink : Palette.inkTertiary)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isSaved)
                    .frame(width: HitTarget.minimum, height: HitTarget.minimum)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSaved ? "Remove from saved" : "Save story")
            .sensoryFeedback(.impact(weight: .light), trigger: isSaved)
        }
        .contentShape(Rectangle())
    }
}
