import SwiftUI

struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(\.services) private var services
    @State private var stories: Loadable<[Story]> = .loading

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
            ToolbarItem(placement: .principal) { BrandHeader() }
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: { Image(systemName: "person").fontWeight(.light) }
                    .accessibilityLabel("Profile")
            }
        }
        .toolbarBackground(Palette.background, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func content(_ all: [Story]) -> some View {
        let featured = all.first { $0.isRecommended } ?? all[0]
        let legends = all.filter { [.myths, .gods, .artifacts].contains($0.category) }
        let places = all.filter { [.places, .history].contains($0.category) && $0.id != featured.id }

        VStack(alignment: .leading, spacing: Spacing.section) {
            hero

            // Story of the day
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(title: "Story of the day", actionTitle: nil)
                StoryLink(story: featured) {
                    FeaturedStoryCard(story: featured, imageHeight: 240)
                }
                .padding(.horizontal, Spacing.screen)
            }

            carousel(title: "Myths & Legends", stories: legends) { PortraitStoryCard(story: $0) }

            carousel(title: "Sacred Places", stories: places) {
                FeaturedStoryCard(story: $0, imageHeight: 180).frame(width: 280)
            }

            QuoteBlock(greek: "Γνῶθι σεαυτόν", english: "Know thyself.", source: "Temple of Apollo, Delphi")
        }
        .padding(.bottom, Spacing.section)
    }

    /// Brand statement over the engraved bust; primary action = Scan.
    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Color.clear
                .frame(height: 300)
                .overlay {
                    Image("hero-bust").resizable().scaledToFill().parallax()
                }
                .clipped()
                .overlay(Palette.fadeToBackground)
                .accessibilityHidden(true)

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

            Button { router.presentScan() } label: {
                Label("Begin a scan", systemImage: "viewfinder")
            }
            .buttonStyle(.primary)
            .padding(.horizontal, Spacing.screen)
            .reveal(order: 3)
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
            }
            .contentMargins(.horizontal, Spacing.screen, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
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

#Preview {
    NavigationStack { HomeView() }
        .environment(Router())
        .environment(LibraryStore())
        .preferredColorScheme(.dark)
}
