import SwiftUI

/// Your Library: who you are in the app (rank and counts), your Odyssey,
/// picture tiles for everything you've kept, recent saves, collections, and
/// the map and settings as glass rows.
struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(HighlightStore.self) private var highlights
    @Environment(PhotoStore.self) private var photos
    @Environment(PermissionsCenter.self) private var permissions
    @State private var showsPermissions = false

    private let tileColumns = [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                header
                OdysseyCard().padding(.horizontal, Spacing.md)
                tiles
                recentlySaved
                collections
                settings
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

    // MARK: Header

    private var header: some View {
        let odyssey = Odyssey(photos: photos.photos)

        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Label(odyssey.rank.title.uppercased(), systemImage: odyssey.rank.symbol)
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 5)
                    .glassSurface(in: Capsule())
                Spacer()
                Text(odyssey.rank.motto)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            HStack(spacing: 0) {
                stat("\(library.savedIDs.count)", "Saved", "bookmark.fill")
                divider
                stat("\(highlights.highlights.count)", "Highlights", "highlighter")
                divider
                stat("\(photos.photos.count)", "Photos", "camera.fill")
                divider
                stat("\(StorylineProgress.watched.count)", "Myths seen", "play.fill")
            }
        }
        .padding(Spacing.md)
        .glassCard(glow: library.savedIDs.first.flatMap(MockData.story)?.artwork)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }

    private func stat(_ value: String, _ label: String, _ symbol: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle().fill(Palette.ink.opacity(0.12)).frame(width: 0.75, height: 40)
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

    // MARK: Shelves

    @ViewBuilder
    private var recentlySaved: some View {
        let saved = library.savedIDs.compactMap(MockData.story)
        if !saved.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "Recently saved", actionTitle: nil)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Spacing.md) {
                        ForEach(saved) { story in
                            StoryLink(story: story) { GlassPortraitCard(story: story, width: 150) }
                                .carouselCard()
                        }
                    }
                    .padding(.vertical, Spacing.lg)
                }
                .contentMargins(.horizontal, Spacing.screen, for: .scrollContent)
                .scrollClipDisabled()
                .padding(.vertical, -Spacing.lg)
            }
        }
    }

    @ViewBuilder
    private var collections: some View {
        if !library.collections.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                SectionHeader(title: "Collections", actionTitle: nil)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Spacing.md) {
                        ForEach(library.collections) { collection in
                            NavigationLink(value: Route.collection(collection.id)) {
                                CollectionMosaic(collection: collection)
                            }
                            .buttonStyle(.pressable)
                            .carouselCard()
                        }
                    }
                    .padding(.vertical, Spacing.lg)
                }
                .contentMargins(.horizontal, Spacing.screen, for: .scrollContent)
                .scrollClipDisabled()
                .padding(.vertical, -Spacing.lg)
            }
        }
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

/// A collection's first four plates as a 2×2 mosaic on a glass card.
private struct CollectionMosaic: View {
    let collection: StoryCollection

    var body: some View {
        let plates = collection.storyIDs.prefix(4).compactMap(MockData.story).map(\.artwork)

        VStack(alignment: .leading, spacing: Spacing.xs) {
            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                GridRow {
                    cell(plates, 0)
                    cell(plates, 1)
                }
                GridRow {
                    cell(plates, 2)
                    cell(plates, 3)
                }
            }
            .frame(width: 176, height: 176)
            .clipShape(RoundedRectangle(cornerRadius: Radius.cardInner - 6, style: .continuous))

            Text(collection.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .padding(.horizontal, Spacing.xxs)
            Text("\(collection.storyIDs.count) stories")
                .font(.system(size: 12))
                .foregroundStyle(Palette.inkTertiary)
                .padding(.horizontal, Spacing.xxs)
                .padding(.bottom, Spacing.xxs)
        }
        .frame(width: 176)
        .padding(Spacing.xs)
        .glassCard(cornerRadius: Radius.cardInner, glow: plates.first)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func cell(_ plates: [Artwork], _ i: Int) -> some View {
        if i < plates.count {
            ArtworkView(artwork: plates[i], motion: false)
        } else {
            Palette.surface
        }
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
