import SwiftUI

/// Your Library: your Odyssey, one picture tile per thing you've kept (each
/// with its count), and the map and settings as glass rows. Its search only
/// looks through what you've kept.
struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(HighlightStore.self) private var highlights
    @Environment(PhotoStore.self) private var photos
    @Environment(PermissionsCenter.self) private var permissions
    @State private var showsPermissions = false
    @State private var query = ""

    private let tileColumns = [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)]

    private var trimmedQuery: String { InputSanitizer.clean(query, maxLength: 80) }

    var body: some View {
        ScrollView {
            if trimmedQuery.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    OdysseyCard().padding(.horizontal, Spacing.md)
                    tiles
                    settings
                    QuoteBlock(greek: "Μνήμη", english: "Memory is the mother of the Muses.", source: "Hesiod, Theogony")
                }
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.section)
            } else {
                LibrarySearchResults(query: trimmedQuery)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .screenBackground()
        .navigationTitle("Library")
        .scopedSearch(text: $query, prompt: "Search Library")
        .sheet(isPresented: $showsPermissions) {
            PermissionsView { showsPermissions = false }
                .presentationDragIndicator(.visible)
        }
        .task { await permissions.refresh() }
    }

    // MARK: Tiles

    /// Everything you've kept, as picture tiles (each shows what's inside).
    private var tiles: some View {
        LazyVGrid(columns: tileColumns, spacing: Spacing.md) {
            NavigationLink(value: Route.library(.saved)) {
                LibraryTile(title: "Saved", symbol: "bookmark.fill", count: library.savedIDs.count,
                            artwork: library.savedIDs.first.flatMap(MockData.story)?.artwork)
            }
            NavigationLink(value: Route.library(.highlights)) {
                LibraryTile(title: "Highlights & Notes", symbol: "highlighter", count: highlights.highlights.count,
                            artwork: highlights.highlights.first.flatMap { MockData.story($0.storyID) }?.artwork)
            }
            NavigationLink(value: Route.photos) {
                LibraryTile(title: "Your Photos", symbol: "photo.on.rectangle.angled", count: photos.photos.count,
                            photo: photos.photos.first)
            }
            NavigationLink(value: Route.library(.offline)) {
                LibraryTile(title: "Offline", symbol: "arrow.down.circle.fill", count: library.offlineIDs.count,
                            artwork: library.offlineIDs.first.flatMap(MockData.story)?.artwork)
            }
            NavigationLink(value: Route.library(.history)) {
                LibraryTile(title: "Scan History", symbol: "clock.arrow.circlepath", count: library.scanHistory.count,
                            artwork: library.scanHistory.first.flatMap { MockData.story($0.storyID) }?.artwork)
            }
            NavigationLink(value: Route.library(.collections)) {
                LibraryTile(title: "Collections", symbol: "square.stack.fill", count: library.collections.count,
                            artwork: library.collections.first?.storyIDs.first.flatMap(MockData.story)?.artwork)
            }
        }
        .buttonStyle(.pressable)
        .padding(.horizontal, Spacing.md)
    }

    // MARK: Settings

    private var settings: some View {
        VStack(spacing: Spacing.sm) {
            NavigationLink(value: Route.map(focus: nil)) {
                SettingsRow(title: "Your Map", subtitle: journeySummary, symbol: "map")
            }
            Button { showsPermissions = true } label: {
                SettingsRow(title: "Permissions & nearby alerts",
                            subtitle: permissions.allGranted ? "Everything is on" : "Some features are off",
                            symbol: permissions.allGranted ? "checkmark.shield" : "exclamationmark.shield")
            }
        }
        .buttonStyle(.pressable)
        .padding(.horizontal, Spacing.md)
    }

    private var journeySummary: String {
        let places = photos.places.count
        return places == 0 ? "No places yet" : "\(places) \(places == 1 ? "place" : "places") · \(photos.photos.count) photos"
    }
}

/// A Library section as a picture tile: what's inside, blurred behind glass,
/// with its icon, name and count.
private struct LibraryTile: View {
    let title: String
    let symbol: String
    let count: Int
    var artwork: Artwork? = nil
    var photo: SitePhoto? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let photo {
                    SitePhotoImage(photo: photo)
                } else if let artwork {
                    ArtworkView(artwork: artwork, motion: false)
                } else {
                    Palette.surface
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .clipped()
            .overlay(LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 36, height: 36)
                    .glassSurface(in: Circle())
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Text("\(count)")
                        .font(.system(size: 15, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .padding(Spacing.sm)
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: Radius.cardInner, style: .continuous))
        .glassCard(cornerRadius: Radius.cardInner)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(count)")
    }
}

/// Library search: only what you've kept — saved and offline stories,
/// highlights and notes, collections and places you've photographed.
private struct LibrarySearchResults: View {
    let query: String
    @Environment(LibraryStore.self) private var library
    @Environment(HighlightStore.self) private var highlights
    @Environment(PhotoStore.self) private var photos

    var body: some View {
        let kept = Array(Set(library.savedIDs + library.offlineIDs)).sorted()
        let stories = kept.compactMap(MockData.story).filter { $0.matches(query) }
        let notes = highlights.highlights.filter {
            $0.text.localizedStandardContains(query) || ($0.note ?? "").localizedStandardContains(query)
        }
        let collections = library.collections.filter { $0.name.localizedStandardContains(query) }
        let places = photos.places.filter {
            $0.name.localizedStandardContains(query) || $0.region.localizedStandardContains(query)
        }

        if stories.isEmpty && notes.isEmpty && collections.isEmpty && places.isEmpty {
            EmptyStateView(symbol: "magnifyingglass", title: "No results",
                           message: "Nothing in your Library matches “\(query)”. Try the Search tab to look everywhere.")
                .padding(.top, Spacing.xl)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !stories.isEmpty {
                    header("Stories")
                    ForEach(stories) { story in
                        StoryLink(story: story) {
                            StoryRow(story: story, isSaved: library.isSaved(story.id)) { library.toggleSaved(story.id) }
                        }
                        .modifier(RowChrome())
                    }
                }
                if !notes.isEmpty {
                    header("Highlights & Notes")
                    ForEach(notes) { highlight in
                        NavigationLink(value: Route.story(highlight.storyID)) { HighlightRow(highlight: highlight) }
                            .buttonStyle(.pressable)
                            .modifier(RowChrome())
                    }
                }
                if !collections.isEmpty {
                    header("Collections")
                    ForEach(collections) { collection in
                        NavigationLink(value: Route.collection(collection.id)) {
                            Label(collection.name, systemImage: LibrarySection.collections.symbol)
                                .textStyle(.headline)
                                .foregroundStyle(Palette.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable)
                        .modifier(RowChrome())
                    }
                }
                if !places.isEmpty {
                    header("Your Places")
                    ForEach(places) { place in
                        NavigationLink(value: Route.album(place.id)) {
                            Label(place.name, systemImage: "photo.on.rectangle")
                                .textStyle(.headline)
                                .foregroundStyle(Palette.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable)
                        .modifier(RowChrome())
                    }
                }
            }
            .padding(.bottom, Spacing.section)
        }
    }

    private func header(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(1.4)
            .foregroundStyle(Palette.inkTertiary)
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.lg)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct SettingsRow: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Palette.ink)
                .frame(width: 40, height: 40)
                .glassSurface(in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkTertiary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(Spacing.sm)
        .glassCard(cornerRadius: Radius.cardInner)
        .accessibilityElement(children: .combine)
    }
}

/// Drill-down list for each library section.
struct LibraryListView: View {
    let section: LibrarySection
    @Environment(LibraryStore.self) private var library
    @Environment(HighlightStore.self) private var highlights

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                switch section {
                case .saved: storyRows(library.savedIDs)
                case .highlights: HighlightsLibraryList()
                case .offline: storyRows(library.offlineIDs)
                case .history:
                    ForEach(library.scanHistory) { record in
                        if let story = MockData.story(record.storyID) {
                            StoryLink(story: story) {
                                HStack(spacing: Spacing.md) {
                                    ArtworkView(artwork: story.artwork)
                                        .frame(width: 56, height: 56)
                                        .clipShape(Circle())
                                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                                        Text(story.title).textStyle(.headline).foregroundStyle(Palette.ink)
                                        Text(record.date, format: .relative(presentation: .named))
                                            .textStyle(.label).foregroundStyle(Palette.inkTertiary)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .modifier(RowChrome())
                        }
                    }
                case .collections:
                    ForEach(library.collections) { collection in
                        NavigationLink(value: Route.collection(collection.id)) {
                            HStack(spacing: Spacing.md) {
                                if let first = collection.storyIDs.first.flatMap(MockData.story) {
                                    ArtworkView(artwork: first.artwork)
                                        .frame(width: 64, height: 64)
                                        .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
                                }
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(collection.name).textStyle(.headline).foregroundStyle(Palette.ink)
                                    Text("\(collection.storyIDs.count) stories")
                                        .textStyle(.label).foregroundStyle(Palette.inkTertiary)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable)
                        .modifier(RowChrome())
                    }
                }
            }
            .padding(.bottom, Spacing.section)
        }
        .screenBackground()
        .navigationTitle(section.title)
        .overlay { if isEmpty { EmptyStateView(symbol: section.symbol, title: "Nothing here yet", message: emptyMessage) } }
    }

    private var emptyMessage: String {
        section == .highlights
            ? "Select a passage in any story to highlight it or add a note."
            : "Stories you add will appear here."
    }

    private var isEmpty: Bool {
        switch section {
        case .saved: library.savedIDs.isEmpty
        case .highlights: highlights.highlights.isEmpty
        case .offline: library.offlineIDs.isEmpty
        case .history: library.scanHistory.isEmpty
        case .collections: library.collections.isEmpty
        }
    }

    @ViewBuilder
    private func storyRows(_ ids: [Story.ID]) -> some View {
        ForEach(ids.compactMap(MockData.story)) { story in
            StoryLink(story: story) {
                StoryRow(story: story, isSaved: library.isSaved(story.id)) { library.toggleSaved(story.id) }
            }
            .modifier(RowChrome())
        }
    }
}

struct CollectionView: View {
    let collectionID: StoryCollection.ID
    @Environment(LibraryStore.self) private var library

    var body: some View {
        let collection = library.collections.first { $0.id == collectionID }
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach((collection?.storyIDs ?? []).compactMap(MockData.story)) { story in
                    StoryLink(story: story) {
                        StoryRow(story: story, isSaved: library.isSaved(story.id)) { library.toggleSaved(story.id) }
                    }
                    .modifier(RowChrome())
                }
            }
        }
        .screenBackground()
        .navigationTitle(collection?.name ?? "Collection")
    }
}

/// Consistent row insets + hairline separator for custom lists.
struct RowChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.md)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.hairline).frame(height: 0.5).padding(.horizontal, Spacing.screen)
            }
    }
}

#Preview("Library") {
    NavigationStack { LibraryView().appDestinations() }
        .previewEnvironment()
}

#Preview("Highlights & Notes") {
    NavigationStack { LibraryListView(section: .highlights).appDestinations() }
        .previewEnvironment()
}

#Preview("Saved") {
    NavigationStack { LibraryListView(section: .saved).appDestinations() }
        .previewEnvironment()
}

#Preview("Collection") {
    NavigationStack { CollectionView(collectionID: "olympians").appDestinations() }
        .previewEnvironment()
}
