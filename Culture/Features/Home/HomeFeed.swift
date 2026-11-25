//
//  HomeFeed.swift
//  Culture
//
//  Created by Mario Martinelli on 25/11/2026.
//

import SwiftUI

// MARK: - Story rings

/// Instagram-style row of circles along the top of Home. Each opens that
/// story's animated storyline; a glowing ring marks the ones not yet watched.
struct StoryRingsRow: View {
    let stories: [Story]
    let watched: Set<Story.ID>
    var onOpen: (Story) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: Spacing.md) {
                ForEach(stories) { story in
                    Button { onOpen(story) } label: {
                        StoryRing(story: story, isWatched: watched.contains(story.id))
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.vertical, Spacing.xxs)
        }
        .contentMargins(.horizontal, Spacing.screen, for: .scrollContent)
    }
}

private struct StoryRing: View {
    let story: Story
    var isWatched: Bool

    @State private var spin = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let size: CGFloat = 70

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ArtworkView(artwork: story.artwork, motion: false)
                .frame(width: size - 10, height: size - 10)
                .clipShape(Circle())
                .padding(3)
                .background(Palette.background, in: Circle())
                .padding(2)
                .background {
                    if isWatched {
                        Circle().strokeBorder(Palette.inkTertiary.opacity(0.5), lineWidth: 1.5)
                    } else {
                        // Unwatched: a slowly turning ring of light, with a soft glow.
                        Circle()
                            .fill(AngularGradient(colors: [Palette.ink, Palette.imageWarmth.opacity(0.35),
                                                           Palette.inkSecondary, Palette.ink],
                                                  center: .center))
                            .rotationEffect(.degrees(spin ? 360 : 0))
                            .shadow(color: Palette.imageWarmth.opacity(0.45), radius: 6)
                    }
                }
                .frame(width: size, height: size)

            Text(story.title.replacingOccurrences(of: "The ", with: ""))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isWatched ? Palette.inkTertiary : Palette.ink)
                .lineLimit(1)
                .frame(width: size + 6)
        }
        .onAppear {
            guard !reduceMotion, !isWatched else { return }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { spin = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Storyline: \(story.title)\(isWatched ? ", watched" : "")")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Feed post

/// A story as an Instagram-style post on a glowing glass card: header,
/// swipeable slides (plate · summary · your photos there), actions, caption.
/// Double-tap the slides to save it, like a "like".
struct FeedPostCard: View {
    let story: Story
    var badge: String? = nil
    var onOpen: () -> Void
    var onStoryline: () -> Void
    var onMap: () -> Void

    @Environment(LibraryStore.self) private var library
    @Environment(PhotoStore.self) private var photoStore
    @State private var page: String?
    @State private var burst = false

    private var slides: [FeedSlide] {
        [.artwork] + story.plates.map { .plate($0) } + [.summary]
            + photoStore.sitePhotos(for: story.id).prefix(3).map { .photo($0) }
    }

    var body: some View {
        let isSaved = library.isSaved(story.id)

        VStack(alignment: .leading, spacing: Spacing.sm) {
            header
            carousel
            actions(isSaved: isSaved)
            caption
        }
        .padding(Spacing.sm)
        .glassCard(glow: story.artwork)
        .sensoryFeedback(.impact(weight: .light), trigger: isSaved)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            ArtworkView(artwork: story.artwork, motion: false)
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Palette.ink.opacity(0.4), lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                Text(story.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text("\(story.region) · \(story.era)")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Menu {
                Button("Read the story", systemImage: "book", action: onOpen)
                Button("Watch the storyline", systemImage: "play.circle", action: onStoryline)
                Button("Show on map", systemImage: "map", action: onMap)
                ShareLink(item: "\(story.title) — \(story.summary)") {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: HitTarget.minimum, height: HitTarget.minimum)
            }
            .accessibilityLabel("More for \(story.title)")
        }
        .padding(.horizontal, Spacing.xxs)
    }

    // MARK: Slides

    private var carousel: some View {
        let slides = slides

        return ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(slides) { slide in
                    slideView(slide)
                        .containerRelativeFrame(.horizontal)
                        .id(slide.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $page)
        .scrollIndicators(.hidden)
        .aspectRatio(4 / 5, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Radius.cardInner, style: .continuous))
        .overlay(alignment: .topLeading) {
            if let badge { GlassPill { Text(badge.uppercased()).tracking(1) }.padding(Spacing.sm) }
        }
        .overlay(alignment: .topTrailing) {
            if slides.count > 1 {
                GlassPill { Text("\(index(in: slides) + 1)/\(slides.count)").monospacedDigit() }
                    .padding(Spacing.sm)
            }
        }
        .overlay(alignment: .bottom) {
            if slides.count > 1 { dots(count: slides.count, current: index(in: slides)) }
        }
        .overlay { heartBurst }
        .onTapGesture(count: 2) { like() }
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(story.title), \(slides.count) slides")
        .accessibilityHint("Swipe for more. Double-tap to open.")
        .accessibilityAction(named: library.isSaved(story.id) ? "Remove from saved" : "Save") { library.toggleSaved(story.id) }
    }

    @ViewBuilder
    private func slideView(_ slide: FeedSlide) -> some View {
        switch slide {
        case .artwork:
            ArtworkView(artwork: story.artwork)
        case .plate(let plate):
            ArtworkView(artwork: plate, engraved: false)
        case .summary:
            ZStack {
                ArtworkView(artwork: story.artwork, motion: false)
                    .blur(radius: 26)
                    .overlay(Color.black.opacity(0.35))
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(story.category.title.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(Palette.inkSecondary)
                    Text(story.summary)
                        .textStyle(.lede)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(7)
                        .minimumScaleFactor(0.8)
                    Text(story.subtitle)
                        .textStyle(.italic)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .padding(Spacing.lg)
                .glassCard(cornerRadius: Radius.cardInner)
                .padding(Spacing.lg)
            }
        case .photo(let photo):
            SitePhotoImage(photo: photo)
                .overlay(alignment: .bottomLeading) {
                    GlassPill { Label("Your photo · \(photo.date.formatted(.dateTime.day().month(.abbreviated)))", systemImage: "camera") }
                        .padding(Spacing.sm)
                        .padding(.bottom, Spacing.md)
                }
        }
    }

    private func index(in slides: [FeedSlide]) -> Int {
        slides.firstIndex { $0.id == page } ?? 0
    }

    private func dots(count: Int, current: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Palette.ink : Palette.ink.opacity(0.4))
                    .frame(width: i == current ? 16 : 6, height: 6)
            }
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, Spacing.sm)
        .animation(Motion.snappy, value: current)
        .accessibilityHidden(true)
    }

    // MARK: Actions & caption

    private func actions(isSaved: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            Button(action: toggleLike) {
                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .foregroundStyle(isSaved ? Palette.imageWarmth : Palette.ink)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isSaved)
            }
            .accessibilityLabel(isSaved ? "Remove from saved" : "Save")

            Button(action: onStoryline) { Image(systemName: "play.circle") }
                .accessibilityLabel("Watch the storyline")

            ShareLink(item: "\(story.title) — \(story.summary)") { Image(systemName: "paperplane") }
                .accessibilityLabel("Share")

            Spacer()

            Button(action: onMap) { Image(systemName: "mappin.and.ellipse") }
                .accessibilityLabel("Show on map")
        }
        .font(.system(size: 21, weight: .regular))
        .foregroundStyle(Palette.ink)
        .buttonStyle(.pressable)
        .padding(.horizontal, Spacing.xs)
        .frame(minHeight: HitTarget.minimum)
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("\(Text(story.title).fontWeight(.semibold)) \(story.summary)")
                .font(.system(size: 14))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
            Button(action: onOpen) {
                Text("Read the story · \(story.durationLabel)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.xs)
        .padding(.bottom, Spacing.xs)
    }

    /// Heart button: save / unsave.
    private func toggleLike() {
        library.toggleSaved(story.id)
        if library.isSaved(story.id) { showBurst() }
    }

    /// Double-tap: always saves (never un-saves), like Instagram.
    private func like() {
        if !library.isSaved(story.id) { library.toggleSaved(story.id) }
        showBurst()
    }

    private func showBurst() {
        burst = true
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            burst = false
        }
    }

    private var heartBurst: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 92))
            .foregroundStyle(Palette.ink)
            .shadow(color: Palette.imageWarmth.opacity(0.8), radius: 18)
            .scaleEffect(burst ? 1 : 0.3)
            .opacity(burst ? 0.95 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: burst)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private enum FeedSlide: Identifiable, Hashable {
    case artwork, summary
    case plate(Artwork)
    case photo(SitePhoto)

    var id: String {
        switch self {
        case .artwork: "artwork"
        case .summary: "summary"
        case .plate(let plate): plate.imageName
        case .photo(let photo): photo.id.uuidString
        }
    }
}

#Preview("Feed") {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            FeedPostCard(story: MockData.story("parthenon")!, badge: "Story of the day",
                         onOpen: {}, onStoryline: {}, onMap: {})
                .padding(.horizontal, Spacing.sm)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(MockData.stories.prefix(4)) { GlassPortraitCard(story: $0) }
                }
                .padding(.vertical, Spacing.lg)
            }
            .contentMargins(.horizontal, Spacing.screen, for: .scrollContent)
            .scrollClipDisabled()
        }
        .padding(.vertical, Spacing.lg)
    }
    .screenBackground()
    .previewEnvironment()
}

// MARK: - Glass portrait card

/// Portrait plate with its caption on a frosted panel, for the horizontal
/// carousels between posts.
struct GlassPortraitCard: View {
    let story: Story
    var width: CGFloat = 176

    var body: some View {
        ArtworkView(artwork: story.artwork)
            .frame(width: width, height: width * 1.36)
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(story.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("\(story.region) · \(story.durationLabel)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.sm)
                .glassCard(cornerRadius: Radius.cardInner - 4)
                .padding(Spacing.xs)
            }
            .glassCard(cornerRadius: Radius.cardInner, glow: story.artwork)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens story")
    }
}
