import SwiftUI

struct StoryDetailView: View {
    let storyID: Story.ID

    @Environment(\.services) private var services
    @Environment(LibraryStore.self) private var library
    @Environment(HighlightStore.self) private var highlightStore
    @Environment(Router.self) private var router
    @State private var story: Story?
    @State private var related: [Story] = []
    @State private var player = StoryNarrator()
    @State private var assistant = StoryAssistant()
    @State private var expanded = false
    @State private var viewingPhotos: PhotoViewerItem?
    @State private var showsStoryline = false

    // Highlighting
    @State private var selection: NSRange?
    @State private var activeHighlightID: Highlight.ID?
    @State private var noteEditing: NoteEditing?

    private struct NoteEditing: Identifiable { let id: Highlight.ID }

    private let heroHeight: CGFloat = 440

    var body: some View {
        Group {
            if let story { content(story) } else { LoadingView() }
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar { if let story { toolbar(story) } }
        // Swipe left from the right edge: the site, nearby sites and your photos on the map.
        .overlay(alignment: .trailing) {
            if let story { MapPullTab { openMap(story) } }
        }
        // AI widget: read aloud, ask questions, language. Out of the way while highlighting.
        .overlay {
            if let story, selection == nil, activeHighlightID == nil {
                StoryAIWidget(story: story, player: player, assistant: assistant)
                    .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let story { actionBar(story) }
        }
        .animation(Motion.snappy, value: selection)
        .animation(Motion.snappy, value: activeHighlightID)
        .sheet(item: $noteEditing) { editing in noteSheet(editing) }
        .fullScreenCover(isPresented: $showsStoryline) {
            if let story {
                // "Read the full story" just closes the player onto the article.
                StorylinePlayer(story: story, scenes: Storyline.scenes(for: story)) {
                    withAnimation(Motion.smooth) { expanded = true }
                }
            }
        }
        .fullScreenCover(item: $viewingPhotos) { item in
            // Already in this story, so no "Read the story" button.
            PhotoViewer(item: item, onShowOnMap: { photo in
                viewingPhotos = nil
                router.open(.map(focus: photo.id, site: storyID))
            })
        }
        .sensoryFeedback(.impact(weight: .light), trigger: highlightStore.highlights.count)
        .onChange(of: selection) { if selection != nil { activeHighlightID = nil } }
        .task(id: storyID) { await load() }
        .onDisappear { player.pause() }
    }

    private func content(_ story: Story) -> some View {
        let marks = highlightStore.highlights(for: story.id)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero(story)

                VStack(alignment: .leading, spacing: Spacing.xl) {
                    header(story)
                    // The tale as animated scenes, before the full text.
                    StorylineCard(story: story, scenes: Storyline.scenes(for: story), isPlaying: !showsStoryline) {
                        player.pause()
                        showsStoryline = true
                    }
                    article(story, highlights: marks)
                }
                .padding(.horizontal, Spacing.screen)

                // Photos the user snapped at this site (the map is a swipe away)
                StoryPhotoGallery(
                    story: story,
                    onOpenPhotos: { photos, start in viewingPhotos = PhotoViewerItem(photos: photos, start: start) },
                    onShowMap: { openMap(story) }
                )
                .padding(.top, Spacing.section)

                if !marks.isEmpty {
                    StoryHighlightsSection(highlights: marks) { highlight in
                        withAnimation(Motion.smooth) { expanded = true }
                        selection = nil
                        activeHighlightID = highlight.id
                    }
                    .padding(.top, Spacing.section)
                }

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
            .padding(.bottom, Spacing.section + 72) // clear of the AI button
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

    private func article(_ story: Story, highlights: [Highlight]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text(story.summary)
                .textStyle(.lede)
                .foregroundStyle(Palette.ink)
            HighlightableText(
                text: story.body,
                highlights: highlights,
                selection: $selection,
                lineLimit: expanded ? nil : 6,
                onTapHighlight: { highlight in
                    selection = nil
                    activeHighlightID = highlight.id
                },
                onMenuAction: { action, range in
                    let created = addHighlight(range, color: highlightStore.lastColor, in: story)
                    if action == .note, let created { noteEditing = NoteEditing(id: created.id) }
                }
            )
            Button(expanded ? "Show less" : "Continue reading") {
                withAnimation(Motion.smooth) { expanded.toggle() }
            }
            .buttonStyle(.secondary)
        }
    }

    // MARK: Highlights

    /// Bottom panel: for a fresh selection, or for a tapped highlight.
    @ViewBuilder
    private func actionBar(_ story: Story) -> some View {
        if let id = activeHighlightID, let highlight = highlightStore.highlight(id: id) {
            HighlightActionBar(
                quote: highlight.text,
                shareText: shareText(highlight.text, story),
                activeColor: highlight.color,
                hasNote: highlight.hasNote,
                onColor: { highlightStore.setColor($0, for: highlight.id) },
                onNote: { noteEditing = NoteEditing(id: highlight.id) },
                onRemove: {
                    highlightStore.remove(highlight.id)
                    activeHighlightID = nil
                },
                onClose: { activeHighlightID = nil }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let range = selection, let quote = substring(of: story.body, range) {
            HighlightActionBar(
                quote: quote,
                shareText: shareText(quote, story),
                onColor: { addHighlight(range, color: $0, in: story) },
                onNote: {
                    if let created = addHighlight(range, color: highlightStore.lastColor, in: story) {
                        noteEditing = NoteEditing(id: created.id)
                    }
                },
                onClose: { selection = nil }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// Creates the highlight and keeps the panel open on it (to add a note or recolour).
    @discardableResult
    private func addHighlight(_ range: NSRange, color: HighlightColor, in story: Story) -> Highlight? {
        let created = highlightStore.add(range, in: story.body, storyID: story.id, color: color)
        selection = nil
        activeHighlightID = created?.id
        return created
    }

    @ViewBuilder
    private func noteSheet(_ editing: NoteEditing) -> some View {
        if let highlight = highlightStore.highlight(id: editing.id) {
            NoteEditorSheet(
                quote: highlight.text,
                color: highlight.color,
                storyTitle: story?.title ?? "",
                note: highlight.note ?? "",
                onSave: { highlightStore.setNote($0, for: highlight.id) },
                onDelete: highlight.hasNote ? { highlightStore.setNote(nil, for: highlight.id) } : nil
            )
        }
    }

    private func shareText(_ quote: String, _ story: Story) -> String {
        "“\(quote)”\n— \(story.title)"
    }

    private func substring(of text: String, _ range: NSRange) -> String? {
        let ns = text as NSString
        guard range.location != NSNotFound, NSMaxRange(range) <= ns.length else { return nil }
        return ns.substring(with: range)
    }

    // MARK: Toolbar

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

    private func openMap(_ story: Story) {
        router.open(.map(site: story.id))
    }

    private func load() async {
        guard let loaded = try? await services.stories.story(id: storyID) else { return }
        story = loaded
        player.load(loaded)
        assistant.load(loaded)
        library.recordRead(loaded.id)
        highlightStore.reconcile(storyID: loaded.id, body: loaded.body)

        let catalog = (try? await services.stories.allStories()) ?? []
        related = services.recommender.similar(to: loaded, in: catalog, limit: 6)
    }
}

#Preview("With highlights") {
    NavigationStack { StoryDetailView(storyID: "sounion").appDestinations() }
        .previewEnvironment()
}

#Preview("No highlights") {
    NavigationStack { StoryDetailView(storyID: "knossos").appDestinations() }
        .previewEnvironment()
}
