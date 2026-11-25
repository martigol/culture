import SwiftUI

/// Home, Instagram style: story rings that open each storyline, the brand
/// hero, then a feed of glowing glass post cards with horizontal carousels
/// slotted in between.
struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(\.services) private var services
    @State private var stories: Loadable<[Story]> = .loading
    @State private var storyline: Story?
    /// Rings already watched (remembered across launches).
    @State private var watchedStorylines = StorylineProgress.watched

    var body: some View {
        ScrollView {
            switch stories {
            case .loading:
                LoadingView()
            case .failed(let message):
                EmptyStateView(symbol: "wifi.exclamationmark", title: "Couldn't load", message: message)
            case .loaded(let all):
                content(all)
            }
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { router.open(.map(focus: nil)) } label: { Image(systemName: "map").fontWeight(.light) }
                    .accessibilityLabel("Your map")
            }
            ToolbarItem(placement: .principal) { BrandHeader() }
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.open(.search) } label: {
                    Image(systemName: "magnifyingglass").fontWeight(.light)
                }
                .accessibilityLabel("Search")
            }
        }
        .toolbarBackground(Palette.background, for: .navigationBar)
        .fullScreenCover(item: $storyline, onDismiss: {
            watchedStorylines = StorylineProgress.watched
            router.openPending()
        }) { story in
            StorylinePlayer(story: story) { shown in
                router.openAfterDismiss(.story(shown.id))
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func content(_ all: [Story]) -> some View {
        let featured = all.first { $0.isRecommended } ?? all[0]
        // Story of the day first, then the rest.
        let feed = [featured] + all.filter { $0.id != featured.id }
        let legends = all.filter { [.myths, .gods, .artifacts].contains($0.category) }
        let places = all.filter { [.places, .history].contains($0.category) }

        LazyVStack(alignment: .leading, spacing: Spacing.xl) {
            StoryRingsRow(stories: feed, watched: watchedStorylines) { openStoryline($0) }
                .padding(.top, Spacing.xs)

            hero(feed)

            // The game: photograph every site.
            OdysseyCard()
                .padding(.horizontal, Spacing.sm)

            ForEach(Array(feed.enumerated()), id: \.element.id) { index, story in
                post(story, badge: index == 0 ? "Story of the day" : nil)

                // Horizontal slides between posts.
                if index == 1, !legends.isEmpty {
                    carousel(title: "Myths & Legends", stories: legends) { GlassPortraitCard(story: $0) }
                }
                if index == 4, !places.isEmpty {
                    carousel(title: "Sacred Places", stories: places) { GlassPortraitCard(story: $0, width: 220) }
                }
            }

            QuoteBlock(greek: "Γνῶθι σεαυτόν", english: "Know thyself.", source: "Temple of Apollo, Delphi")
                .padding(.top, Spacing.lg)
        }
        .padding(.bottom, Spacing.section)
    }

    private func post(_ story: Story, badge: String?) -> some View {
        FeedPostCard(
            story: story,
            badge: badge,
            onOpen: { router.open(.story(story.id)) },
            onStoryline: { openStoryline(story) },
            onMap: { router.open(.map(site: story.id)) }
        )
        .padding(.horizontal, Spacing.sm)
        .listRowEntrance()
    }

    private func openStoryline(_ story: Story) {
        watchedStorylines.insert(story.id)
        storyline = story
    }

    /// Brand statement over a slideshow of every story (Scan lives in the tab bar).
    private func hero(_ stories: [Story]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HeroSlideshow(stories: stories) { router.open(.story($0.id)) }
                .frame(height: 300)

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Every stone\nhas a story.")
                    .textStyle(.hero)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                    .reveal(order: 1)
                Text("Point your camera at a statue, temple or relic and hear the myth behind it.")
                    .textStyle(.body)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .reveal(order: 2)
            }
            .padding(.horizontal, Spacing.screen)
        }
    }

    private func carousel<Card: View>(title: String, stories: [Story],
                                      @ViewBuilder card: @escaping (Story) -> Card) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: title) { router.selectedTab = .stories }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: Spacing.md) {
                    ForEach(stories) { story in
                        StoryLink(story: story) { card(story) }
                            .carouselCard()
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, Spacing.lg) // room for the cards' glow
            }
            .contentMargins(.horizontal, Spacing.screen, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollClipDisabled()
            .padding(.vertical, -Spacing.lg)
        }
    }

    private func load() async {
        do { stories = .loaded(try await services.stories.allStories()) }
        catch is CancellationError {}
        catch {
            Log.app.error("Home load failed: \(error.localizedDescription)")
            stories = .failed("Please check your connection and try again.")
        }
    }
}

/// The hero image: every story in turn. Each slowly pushes in (Ken Burns),
/// then crossfades into the next; a glass caption names it and opens it.
private struct HeroSlideshow: View {
    let stories: [Story]
    var onOpen: (Story) -> Void

    @State private var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Seconds each story stays on screen.
    private var hold: Double { reduceMotion ? 6 : 5 }

    var body: some View {
        let story = stories.isEmpty ? nil : stories[index % stories.count]

        ZStack {
            Palette.background
            if let story {
                KenBurnsArtwork(artwork: story.artwork, duration: hold + 1.4, animates: !reduceMotion)
                    .id(story.id)
                    .transition(.opacity)
            }
        }
        .clipped()
        .overlay(Palette.fadeToBackground.allowsHitTesting(false))
        .overlay(alignment: .topTrailing) {
            if let story {
                // One caption whose text crossfades, so two never overlap.
                Button { onOpen(story) } label: {
                    GlassPill {
                        HStack(spacing: 4) {
                            Text("\(story.title) · \(story.region)")
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .contentTransition(.opacity)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .frame(maxWidth: 240, alignment: .trailing)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .buttonStyle(.pressable)
                .padding(Spacing.md)
                .accessibilityLabel("Open \(story.title)")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if let story { onOpen(story) } }
        .task(id: index) {
            guard stories.count > 1 else { return }
            try? await Task.sleep(for: .seconds(hold))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: reduceMotion ? 0.6 : 1.4)) { index += 1 }
        }
        .accessibilityElement(children: .contain)
    }
}

/// One slide: the story's plate, slowly zooming and drifting while it's shown.
private struct KenBurnsArtwork: View {
    let artwork: Artwork
    let duration: Double
    var animates = true

    @State private var moved = false

    var body: some View {
        ArtworkView(artwork: artwork, motion: false)
            .scaleEffect(moved ? 1.14 : 1.02)
            .offset(x: moved ? -10 : 8, y: moved ? -6 : 4)
            .scrollParallax(travel: 14)
            .onAppear {
                guard animates else { return }
                withAnimation(.linear(duration: duration)) { moved = true }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack { HomeView().appDestinations() }
        .previewEnvironment()
}
