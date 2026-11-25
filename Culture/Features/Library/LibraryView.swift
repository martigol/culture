import SwiftUI

struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(HighlightStore.self) private var highlights
    @Environment(PhotoStore.self) private var photos
    @Environment(PermissionsCenter.self) private var permissions
    @State private var showsPermissions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                journeyCard

                VStack(spacing: 0) {
                    NavigationLink(value: Route.odyssey) {
                        rowLabel(title: "Your Odyssey", symbol: Odyssey(photos: photos.photos).rank.symbol,
                                 count: photos.capturedSiteIDs.count)
                    }
                    .buttonStyle(.pressable)
                    .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 0.5) }

                    NavigationLink(value: Route.photos) {
                        rowLabel(title: "Your Photos", symbol: "photo.on.rectangle.angled", count: photos.photos.count)
                    }
                    .buttonStyle(.pressable)
                    .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 0.5) }

                    ForEach(Array(LibrarySection.allCases.enumerated()), id: \.element) { index, section in
                        NavigationLink(value: Route.library(section)) { row(section) }
                            .buttonStyle(.pressable)
                            .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 0.5) }
                    }

                    Button { showsPermissions = true } label: {
                        rowLabel(title: "Permissions & nearby alerts",
                                 symbol: permissions.allGranted ? "checkmark.shield" : "exclamationmark.shield",
                                 count: nil)
                    }
                    .buttonStyle(.pressable)
                }
                .padding(.horizontal, Spacing.screen)

                if let recent = library.savedIDs.first.flatMap(MockData.story) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        SectionHeader(title: "Recently saved", actionTitle: nil)
                        StoryLink(story: recent) {
                            FeaturedStoryCard(story: recent, imageHeight: 200)
                        }
                        .padding(.horizontal, Spacing.screen)
                    }
                }

                QuoteBlock(greek: "Μνήμη", english: "Memory is the mother of the Muses.", source: "Hesiod, Theogony")
            }
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.section)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .navigationTitle("Library")
        .sheet(isPresented: $showsPermissions) {
            PermissionsView { showsPermissions = false }
                .presentationDragIndicator(.visible)
        }
        .task { await permissions.refresh() }
    }

    /// Latest pinned places; opens "Your Map".
    private var journeyCard: some View {
        NavigationLink(value: Route.map(focus: nil)) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                PinnedPlacesPreview(height: 180)
                HStack(alignment: .firstTextBaseline) {
                    Text("Your Map").textStyle(.headline).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(journeySummary)
                        .textStyle(.label)
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkTertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .padding(.horizontal, Spacing.screen)
        .accessibilityLabel("Your Map, \(journeySummary)")
    }

    private var journeySummary: String {
        let places = photos.places.count
        return places == 0 ? "No places yet" : "\(places) \(places == 1 ? "place" : "places") · \(photos.photos.count) photos"
    }

    private func row(_ section: LibrarySection) -> some View {
        rowLabel(title: section.title, symbol: section.symbol, count: count(for: section))
    }

    private func rowLabel(title: String, symbol: String, count: Int?) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Palette.ink)
                .frame(width: 24)
            Text(title)
                .textStyle(.headline)
                .foregroundStyle(Palette.ink)
            Spacer()
            if let count {
                Text("\(count)")
                    .textStyle(.label)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Palette.inkTertiary)
        }
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }

    private func count(for section: LibrarySection) -> Int {
        switch section {
        case .saved: library.savedIDs.count
        case .highlights: highlights.highlights.count
        case .offline: library.offlineIDs.count
        case .history: library.scanHistory.count
        case .collections: library.collections.count
        }
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
