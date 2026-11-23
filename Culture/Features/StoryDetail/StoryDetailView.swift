import SwiftUI

struct StoryDetailView: View {
    let storyID: Story.ID

    @Environment(\.services) private var services
    @Environment(LibraryStore.self) private var library
    @State private var story: Story?
    @State private var related: [Story] = []
    @State private var player = AudioPlayer()
    @State private var expanded = false

    private let heroHeight: CGFloat = 440

    var body: some View {
        Group {
            if let story { content(story) } else { LoadingView() }
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar { if let story { toolbar(story) } }
        .task(id: storyID) { await load() }
        .onDisappear { player.pause() }
    }

    private func content(_ story: Story) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero(story)

                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header(story)
                    AudioPlayerCard(player: player)
                    article(story)
                }
                .padding(.horizontal, Spacing.screen)

                if !related.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        SectionHeader(title: "Continue the journey", actionTitle: nil)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: Spacing.md) {
                                ForEach(related) { item in
                                    StoryLink(story: item) { StoryTile(story: item) }
                                }
                            }
                        }
                        .contentMargins(.horizontal, Spacing.screen, for: .scrollContent)
                    }
                    .padding(.top, Spacing.section)
                }

                Text("Plate after a photograph by \(story.artwork.credit)")
                    .textStyle(.footnote)
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(.horizontal, Spacing.screen)
                    .padding(.top, Spacing.xxl)
            }
            .padding(.bottom, Spacing.section)
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
    }

    /// Stretchy engraved plate fading into the page.
    private func hero(_ story: Story) -> some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .scrollView).minY
            ArtworkView(artwork: story.artwork)
                .frame(width: geo.size.width, height: heroHeight + max(0, minY))
                .overlay(Palette.fadeToBackground)
                .offset(y: -max(0, minY))
        }
        .frame(height: heroHeight)
    }

    private func header(_ story: Story) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(story.title)
                .textStyle(.display)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(story.subtitle)
                .textStyle(.italic)
                .foregroundStyle(Palette.inkSecondary)

            HStack(alignment: .top, spacing: Spacing.lg) {
                fact("Theme", story.category.title)
                fact("Place", story.region)
                fact("Era", story.era)
            }
            .padding(.top, Spacing.sm)
        }
        .padding(.top, -Spacing.xxl) // title sits into the fade
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(label).textStyle(.footnote).foregroundStyle(Palette.inkTertiary)
            Text(value).textStyle(.callout).foregroundStyle(Palette.ink).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func article(_ story: Story) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text(story.summary)
                .textStyle(.lede)
                .foregroundStyle(Palette.ink)
            Text(story.body)
                .textStyle(.body)
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(expanded ? nil : 6)
            Button(expanded ? "Show less" : "Continue reading") {
                withAnimation(Motion.smooth) { expanded.toggle() }
            }
            .buttonStyle(.secondary)
        }
    }

    @ToolbarContentBuilder
    private func toolbar(_ story: Story) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { library.toggleSaved(story.id) } label: {
                Image(systemName: library.isSaved(story.id) ? "bookmark.fill" : "bookmark")
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(library.isSaved(story.id) ? "Remove from library" : "Save to library")
            .sensoryFeedback(.success, trigger: library.isSaved(story.id))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { library.toggleOffline(story.id) } label: {
                    Label(library.isOffline(story.id) ? "Remove Download" : "Download for Offline",
                          systemImage: library.isOffline(story.id) ? "trash" : "arrow.down.circle")
                }
                ShareLink(item: "\(story.title) — \(story.summary)") {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("More")
        }
    }

    private func load() async {
        guard let s = try? await services.stories.story(id: storyID) else { return }
        story = s
        player.load(duration: s.audioDurationSeconds)
        related = (try? await services.stories.related(to: s)) ?? []
    }
}

#Preview {
    NavigationStack { StoryDetailView(storyID: "sounion") }
        .environment(LibraryStore())
        .preferredColorScheme(.dark)
}
