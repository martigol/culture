import SwiftUI

/// "For You" — personalised recommendations and themes.
struct DiscoverView: View {
    @Environment(\.services) private var services
    @Environment(Router.self) private var router
    @State private var state: Loadable<[Story]> = .loading
    @State private var heroPage: Story.ID?

    var body: some View {
        ScrollView {
            switch state {
            case .loading: LoadingView()
            case .failed(let msg): EmptyStateView(symbol: "sparkles", title: "Nothing yet", message: msg)
            case .loaded(let stories): content(stories)
            }
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .navigationTitle("For You")
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func content(_ stories: [Story]) -> some View {
        let picks = stories.filter(\.isRecommended)
        let more = stories.filter { !$0.isRecommended }

        VStack(alignment: .leading, spacing: Spacing.section) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Chosen from your interests and recent scans.")
                    .textStyle(.italic)
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.horizontal, Spacing.screen)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: Spacing.md) {
                        ForEach(picks) { story in
                            StoryLink(story: story) {
                                FeaturedStoryCard(story: story, imageHeight: 300, showsTag: true)
                                    .containerRelativeFrame(.horizontal) { w, _ in w - Spacing.screen * 2 }
                            }
                            .carouselCard()
                            .id(story.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, Spacing.screen, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $heroPage)

                PageDots(count: picks.count, current: picks.firstIndex { $0.id == heroPage } ?? 0)
                    .padding(.horizontal, Spacing.screen)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(title: "You might also like", actionTitle: nil)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: Spacing.md) {
                        ForEach(more) { story in
                            StoryLink(story: story) { StoryTile(story: story) }
                                .carouselCard()
                        }
                    }
                }
                .contentMargins(.horizontal, Spacing.screen, for: .scrollContent)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(title: "Browse by theme", actionTitle: nil)
                themeList
            }
        }
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.section)
    }

    /// Index-style theme list (like a book's table of contents).
    private var themeList: some View {
        VStack(spacing: 0) {
            ForEach(Array(StoryCategory.allCases.enumerated()), id: \.element) { index, category in
                Button { router.openStories(filteredBy: category) } label: {
                    HStack(spacing: Spacing.md) {
                        ArtworkView(artwork: Artwork(imageName: category.coverImage, credit: ""))
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
                        Text(category.title)
                            .textStyle(.headline)
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    .padding(.vertical, Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .overlay(alignment: .bottom) {
                    if index < StoryCategory.allCases.count - 1 {
                        Rectangle().fill(Palette.hairline).frame(height: 0.5)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.screen)
    }

    private func load() async {
        do { state = .loaded(try await services.stories.recommendations()) }
        catch is CancellationError {}
        catch { state = .failed("We couldn't load recommendations.") }
    }
}

struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Palette.ink : Palette.hairline)
                    .frame(width: i == current ? 16 : 6, height: 6)
            }
        }
        .animation(Motion.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

#Preview { NavigationStack { DiscoverView() }.environment(Router()).preferredColorScheme(.dark) }
