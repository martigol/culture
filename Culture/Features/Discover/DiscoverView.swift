import SwiftUI

/// "For You": personalised recommendations and themes.
///
/// Ranking comes from `services.recommender`, fed with what the reader did in
/// the app: scans, saves, highlights and stories opened. It's recomputed
/// whenever those change, so the page reacts right after a scan or a save.
struct DiscoverView: View {
    @Environment(\.services) private var services
    @Environment(Router.self) private var router
    @Environment(LibraryStore.self) private var library
    @Environment(HighlightStore.self) private var highlights
    @State private var catalog: Loadable<[Story]> = .loading
    @State private var heroPage: Story.ID?

    private var signals: UserSignals {
        UserSignals(
            scannedIDs: library.scanHistory.map(\.storyID),
            savedIDs: library.savedIDs,
            highlightCounts: highlights.countsByStory,
            readIDs: library.readIDs
        )
    }

    var body: some View {
        ScrollView {
            switch catalog {
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
        let signals = self.signals
        let ranked = services.recommender.recommend(from: stories, signals: signals, limit: stories.count)
        let picks = Array(ranked.prefix(5))
        let more = Array(ranked.dropFirst(5))
        let lastScan = signals.scannedIDs.first.flatMap { id in stories.first { $0.id == id } }
        let fromScan = lastScan.map { services.recommender.similar(to: $0, in: stories, limit: 6) } ?? []

        VStack(alignment: .leading, spacing: Spacing.section) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text(signals.isEmpty
                     ? "Scan, save and highlight stories, and this page will learn what you love."
                     : "Chosen from your scans, saves and highlights.")
                    .textStyle(.italic)
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.horizontal, Spacing.screen)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: Spacing.md) {
                        ForEach(picks) { pick in
                            StoryLink(story: pick.story) {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    FeaturedStoryCard(story: pick.story, imageHeight: 300)
                                    ReasonLabel(reason: pick.reason)
                                }
                                .containerRelativeFrame(.horizontal) { w, _ in w - Spacing.screen * 2 }
                            }
                            .carouselCard()
                            .id(pick.id)
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

            if let lastScan, !fromScan.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SectionHeader(title: "From your last scan", actionTitle: nil)
                    Text("More like \(lastScan.title)")
                        .textStyle(.italic)
                        .foregroundStyle(Palette.inkSecondary)
                        .padding(.horizontal, Spacing.screen)
                    tileRow(fromScan)
                }
            }

            if !more.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SectionHeader(title: "You might also like", actionTitle: nil)
                    tileRow(more.map(\.story))
                }
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(title: "Browse by theme", actionTitle: nil)
                themeList
            }
        }
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.section)
        .animation(Motion.smooth, value: ranked.map(\.id))
    }

    private func tileRow(_ stories: [Story]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: Spacing.md) {
                ForEach(stories) { story in
                    StoryLink(story: story) { StoryTile(story: story) }
                        .carouselCard()
                }
            }
        }
        .contentMargins(.horizontal, Spacing.screen, for: .scrollContent)
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
        do { catalog = .loaded(try await services.stories.allStories()) }
        catch is CancellationError {}
        catch { catalog = .failed("We couldn't load recommendations.") }
    }
}

/// "Because you scanned The Mask of Agamemnon", placed below a card's meta.
struct ReasonLabel: View {
    let reason: Recommendation.Reason

    var body: some View {
        Label {
            Text(reason.text).lineLimit(1)
        } icon: {
            Image(systemName: reason.symbol).fontWeight(.light)
        }
        .textStyle(.footnote)
        .foregroundStyle(Palette.inkSecondary)
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

#Preview("For You") {
    NavigationStack { DiscoverView().appDestinations() }
        .previewEnvironment()
}

#Preview("Reason labels") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        ReasonLabel(reason: .scanned("The Mask of Agamemnon"))
        ReasonLabel(reason: .highlighted("Poseidon's Watch"))
        ReasonLabel(reason: .saved("The Parthenon"))
        ReasonLabel(reason: .read("Medusa"))
        ReasonLabel(reason: .editorsPick)
        ReasonLabel(reason: .explore("Sacred Places"))
    }
    .padding(Spacing.screen)
    .frame(maxWidth: .infinity, alignment: .leading)
    .screenBackground()
    .preferredColorScheme(.dark)
}

#Preview("Page dots") {
    PageDots(count: 5, current: 2)
        .padding(Spacing.screen)
        .screenBackground()
        .preferredColorScheme(.dark)
}
