import SwiftUI

/// The story catalogue. Browsing everything: a cinematic spotlight carousel,
/// then a shelf per theme. Picking a theme or searching: a two-column grid
/// of glass cards. Theme pills stay pinned while scrolling.
struct StoriesView: View {
    enum Filter: Hashable { case all, category(StoryCategory) }

    @Environment(\.services) private var services
    @Environment(LibraryStore.self) private var library
    @Environment(Router.self) private var router
    @State private var stories: Loadable<[Story]> = .loading
    @State private var filter: Filter = .all
    @State private var query = ""
    @State private var storyline: Story?

    private var filters: [Filter] { [.all] + StoryCategory.allCases.map(Filter.category) }
    private let columns = [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                Section {
                    switch stories {
                    case .loading: LoadingView()
                    case .failed(let msg): EmptyStateView(symbol: "book", title: "Couldn't load", message: msg)
                    case .loaded(let all): content(all)
                    }
                } header: {
                    themePills
                }
            }
            .padding(.bottom, Spacing.section)
            .animation(Motion.smooth, value: filter)
            .animation(Motion.smooth, value: query)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .navigationTitle("Stories")
        .scopedSearch(text: $query, prompt: "Search Stories")
        .fullScreenCover(item: $storyline, onDismiss: router.openPending) { story in
            StorylinePlayer(story: story) { shown in router.openAfterDismiss(.story(shown.id)) }
        }
        .task { await load() }
        .onAppear(perform: applyPendingFilter)
        .onChange(of: router.pendingStoriesFilter) { applyPendingFilter() }
    }

    private func applyPendingFilter() {
        guard let category = router.pendingStoriesFilter else { return }
        filter = .category(category)
        router.pendingStoriesFilter = nil
    }

    // MARK: Header

    private var themePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(filters, id: \.self) { item in
                    let isSelected = item == filter
                    Button { withAnimation(Motion.snappy) { filter = item } } label: {
                        HStack(spacing: 6) {
                            if case .category(let c) = item {
                                ArtworkView(artwork: Artwork(imageName: c.coverImage, credit: ""), motion: false)
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                            }
                            Text(title(of: item))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(isSelected ? Palette.onAccent : Palette.ink)
                        .padding(.leading, isCategory(item) ? 6 : Spacing.md)
                        .padding(.trailing, Spacing.md)
                        .frame(minHeight: 38)
                        .background { if isSelected { Capsule().fill(Palette.accent) } }
                        .glassSurface(in: Capsule(), tint: isSelected ? Palette.accent : nil)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, Spacing.xs)
        }
        .contentMargins(.horizontal, Spacing.md, for: .scrollContent)
        .background(LinearGradient(colors: [Palette.background, Palette.background.opacity(0.85), Palette.background.opacity(0)],
                                   startPoint: .top, endPoint: .bottom))
        .sensoryFeedback(.selection, trigger: filter)
    }

    private func title(of filter: Filter) -> String {
        switch filter {
        case .all: "All"
        case .category(let c): c.title
        }
    }

    private func isCategory(_ filter: Filter) -> Bool {
        if case .category = filter { return true }
        return false
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ all: [Story]) -> some View {
        let isBrowsing = filter == .all && InputSanitizer.clean(query).isEmpty
        if isBrowsing {
            browse(all)
        } else {
            grid(filtered(all))
        }
    }

    /// Spotlight carousel, then one shelf per theme.
    private func browse(_ all: [Story]) -> some View {
        let spotlight = all.filter { Storyline.storyIDs.contains($0.id) }.prefix(8)

        return VStack(alignment: .leading, spacing: Spacing.xl) {
            SpotlightCarousel(stories: Array(spotlight)) { storyline = $0 }

            ForEach(StoryCategory.allCases) { category in
                let shelf = all.filter { $0.category == category }
                if !shelf.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        SectionHeader(title: category.title, actionTitle: "See all") {
                            withAnimation(Motion.snappy) { filter = .category(category) }
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: Spacing.md) {
                                ForEach(shelf) { story in
                                    StoryLink(story: story) { GlassPortraitCard(story: story, width: 168) }
                                        .carouselCard()
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.vertical, Spacing.lg)
                        }
                        .contentMargins(.horizontal, Spacing.screen, for: .scrollContent)
                        .scrollTargetBehavior(.viewAligned)
                        .scrollClipDisabled()
                        .padding(.vertical, -Spacing.lg)
                    }
                }
            }
        }
        .padding(.top, Spacing.sm)
        .transition(.opacity)
    }

    @ViewBuilder
    private func grid(_ items: [Story]) -> some View {
        if items.isEmpty {
            EmptyStateView(symbol: "magnifyingglass", title: "No matches", message: "Try another search or theme.")
                .padding(.top, Spacing.xl)
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("\(items.count) \(items.count == 1 ? "story" : "stories")".uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Palette.inkTertiary)
                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    ForEach(items) { story in
                        StoryLink(story: story) {
                            StoryGridCard(story: story, isSaved: library.isSaved(story.id)) {
                                library.toggleSaved(story.id)
                            }
                        }
                        .listRowEntrance()
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.sm)
            .transition(.opacity)
        }
    }

    private func filtered(_ all: [Story]) -> [Story] {
        let q = InputSanitizer.clean(query)
        return all.filter { story in
            let matchesFilter: Bool = {
                if case .category(let c) = filter { return story.category == c }
                return true
            }()
            let matchesQuery = q.isEmpty || story.matches(q)
            return matchesFilter && matchesQuery
        }
    }

    private func load() async {
        do { stories = .loaded(try await services.stories.allStories()) }
        catch is CancellationError {}
        catch { stories = .failed("Please try again.") }
    }
}

// MARK: - Spotlight

/// Big paging cards for the stories with storylines: the plate, the title,
/// and "Watch storyline" — with dots below.
private struct SpotlightCarousel: View {
    let stories: [Story]
    var onWatch: (Story) -> Void

    @State private var current: Story.ID?

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.md) {
                    ForEach(stories) { story in
                        card(story)
                            .containerRelativeFrame(.horizontal) { width, _ in width - Spacing.md * 2 - 24 }
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.94)
                                    .opacity(phase.isIdentity ? 1 : 0.7)
                            }
                            .id(story.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, Spacing.lg)
            }
            .contentMargins(.horizontal, Spacing.md + 12, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $current)
            .scrollClipDisabled()
            .padding(.vertical, -Spacing.lg)

            HStack(spacing: 5) {
                ForEach(stories) { story in
                    let isCurrent = story.id == (current ?? stories.first?.id)
                    Capsule()
                        .fill(isCurrent ? Palette.ink : Palette.ink.opacity(0.3))
                        .frame(width: isCurrent ? 18 : 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(Motion.snappy, value: current)
            .accessibilityHidden(true)
        }
    }

    private func card(_ story: Story) -> some View {
        StoryLink(story: story) {
            ZStack(alignment: .bottomLeading) {
                ArtworkView(artwork: story.artwork)
                    .frame(height: 380)
                LinearGradient(colors: [.clear, .black.opacity(0.35), .black.opacity(0.9)],
                               startPoint: .center, endPoint: .bottom)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    GlassPill { Text(story.category.title.uppercased()).tracking(1) }
                    Text(story.title)
                        .textStyle(.display)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(story.subtitle)
                        .textStyle(.italic)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                    HStack(spacing: Spacing.sm) {
                        Button { onWatch(story) } label: {
                            Label("Watch storyline", systemImage: "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.onAccent)
                                .padding(.horizontal, Spacing.md)
                                .frame(minHeight: 40)
                                .background(Palette.accent, in: Capsule())
                                .glassSurface(in: Capsule(), tint: Palette.accent)
                        }
                        .buttonStyle(.pressable)
                        Text("\(story.region) · \(story.durationLabel)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Palette.inkSecondary)
                            .lineLimit(1)
                    }
                    .padding(.top, Spacing.xxs)
                }
                .padding(Spacing.md)
            }
            .glassCard(glow: story.artwork)
        }
    }
}

// MARK: - Grid card

/// A story in the filtered grid: tall plate, glass caption, bookmark.
private struct StoryGridCard: View {
    let story: Story
    var isSaved: Bool
    var onToggleSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ArtworkView(artwork: story.artwork)
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: Radius.cardInner - 6, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Button(action: onToggleSave) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSaved ? Palette.onAccent : Palette.ink)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 32, height: 32)
                            .background { if isSaved { Circle().fill(Palette.accent) } }
                            .glassSurface(in: Circle(), tint: isSaved ? Palette.accent : nil)
                    }
                    .buttonStyle(.pressable)
                    .padding(Spacing.xs)
                    .accessibilityLabel(isSaved ? "Remove from saved" : "Save story")
                    .sensoryFeedback(.impact(weight: .light), trigger: isSaved)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(story.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                Text("\(story.region) · \(story.durationLabel)")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, Spacing.xxs)
            .padding(.bottom, Spacing.xxs)
        }
        .padding(Spacing.xs)
        .glassCard(cornerRadius: Radius.cardInner, glow: story.artwork)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { StoriesView().appDestinations() }
        .previewEnvironment()
}
