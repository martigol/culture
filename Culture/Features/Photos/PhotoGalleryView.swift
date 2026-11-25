//
//  PhotoGalleryView.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import SwiftUI

/// The Gallery: every photo snapped at a site, organised two ways.
/// - **Places**: one album card per site (curved glass cards, two per row);
///   an album opens that site's photos.
/// - **All photos**: a timeline grouped by month.
/// A stats card on top summarises the collection and opens the map.
struct PhotoGalleryView: View {
    @Environment(PhotoStore.self) private var store
    @Environment(Router.self) private var router
    @State private var mode: Mode = .places
    @State private var viewing: PhotoViewerItem?

    enum Mode: String, CaseIterable, Identifiable {
        case places = "Places", all = "All photos"
        var id: String { rawValue }
    }

    private let albumColumns = [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)]

    var body: some View {
        ScrollView {
            if store.photos.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    statsCard
                    ModeSwitch(selection: $mode)
                    switch mode {
                    case .places: albums
                    case .all: timeline
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.section)
                .animation(Motion.smooth, value: mode)
            }
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .navigationTitle("Gallery")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.map(focus: nil)) {
                    Image(systemName: "map").fontWeight(.light)
                }
                .accessibilityLabel("Your map")
            }
        }
        .fullScreenCover(item: $viewing, onDismiss: router.openPending) { item in
            PhotoViewer(
                item: item,
                onOpenStory: { id in
                    router.openAfterDismiss(.story(id))
                    viewing = nil
                },
                onShowOnMap: { photo in
                    router.openAfterDismiss(.map(focus: photo.id, site: photo.storyID))
                    viewing = nil
                }
            )
        }
    }

    // MARK: Header

    private var statsCard: some View {
        let monthStart = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
        let thisMonth = store.photos.filter { $0.date >= monthStart }.count

        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: 0) {
                stat("\(store.photos.count)", store.photos.count == 1 ? "photo" : "photos")
                divider
                stat("\(store.places.count)", store.places.count == 1 ? "place" : "places")
                divider
                stat("\(thisMonth)", "this month")
            }
            NavigationLink(value: Route.map(focus: nil)) {
                Label("Open your map", systemImage: "map")
            }
            .buttonStyle(.secondary)
        }
        .padding(Spacing.md)
        .glassCard(glow: store.photos.first.flatMap { MockData.story($0.storyID ?? "")?.artwork })
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .textStyle(.title)
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
            Text(label)
                .textStyle(.label)
                .foregroundStyle(Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle().fill(Palette.ink.opacity(0.15)).frame(width: 0.75, height: 32)
    }

    // MARK: Places

    private var albums: some View {
        LazyVGrid(columns: albumColumns, spacing: Spacing.md) {
            ForEach(store.places) { place in
                NavigationLink(value: Route.album(place.id)) {
                    AlbumCard(place: place)
                }
                .buttonStyle(.pressable)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .leading)))
    }

    // MARK: All photos

    private var timeline: some View {
        LazyVStack(alignment: .leading, spacing: Spacing.lg, pinnedViews: [.sectionHeaders]) {
            ForEach(Self.months(of: store.photos), id: \.start) { month in
                Section {
                    PhotoGrid(photos: month.photos) { photo in
                        viewing = PhotoViewerItem(photos: store.photos, start: photo)
                    }
                } header: {
                    HStack {
                        Text(month.start.formatted(.dateTime.month(.wide).year()))
                            .textStyle(.headline)
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Text("\(month.photos.count)")
                            .textStyle(.label)
                            .monospacedDigit()
                            .foregroundStyle(Palette.inkTertiary)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.xs)
                    .glassSurface(in: Capsule())
                    .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    /// Photos (newest first) grouped by calendar month.
    private static func months(of photos: [SitePhoto]) -> [(start: Date, photos: [SitePhoto])] {
        let calendar = Calendar.current
        var order: [Date] = []
        var groups: [Date: [SitePhoto]] = [:]
        for photo in photos {
            let start = calendar.dateInterval(of: .month, for: photo.date)?.start ?? photo.date
            if groups[start] == nil { order.append(start) }
            groups[start, default: []].append(photo)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            EmptyStateView(symbol: "photo.on.rectangle.angled", title: "No photos yet",
                           message: "Photos you take at a site appear here, organised by place and pinned to where you took them.")
            Button("Take your first photo") { router.presentScan() }
                .buttonStyle(.primary)
                .padding(.horizontal, Spacing.screen)
        }
        .padding(.top, Spacing.xxl)
    }
}

// MARK: - Album

/// One site's photos: header with the place and its story, then the grid.
struct PlaceAlbumView: View {
    let placeID: String

    @Environment(PhotoStore.self) private var store
    @Environment(Router.self) private var router
    @State private var viewing: PhotoViewerItem?

    private var place: VisitedPlace? { store.places.first { $0.id == placeID } }

    var body: some View {
        ScrollView {
            if let place {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header(place)
                    PhotoGrid(photos: place.photos) { photo in
                        viewing = PhotoViewerItem(photos: place.photos, start: photo)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.section)
            } else {
                EmptyStateView(symbol: "photo", title: "No photos here", message: "This album is empty.")
                    .padding(.top, Spacing.xxl)
            }
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .navigationTitle(place?.name ?? "Album")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $viewing, onDismiss: router.openPending) { item in
            PhotoViewer(
                item: item,
                onOpenStory: { id in
                    router.openAfterDismiss(.story(id))
                    viewing = nil
                },
                onShowOnMap: { photo in
                    router.openAfterDismiss(.map(focus: photo.id, site: photo.storyID))
                    viewing = nil
                }
            )
        }
    }

    private func header(_ place: VisitedPlace) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SitePhotoImage(photo: place.cover)
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Radius.cardInner, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    GlassPill { Text("\(place.photos.count) \(place.photos.count == 1 ? "photo" : "photos")") }
                        .padding(Spacing.sm)
                }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(place.name)
                    .textStyle(.title)
                    .foregroundStyle(Palette.ink)
                Text([place.region, "Last visit \(place.lastVisit.formatted(date: .abbreviated, time: .omitted))"]
                    .filter { !$0.isEmpty }.joined(separator: " · "))
                    .textStyle(.label)
                    .foregroundStyle(Palette.inkTertiary)
            }
            .padding(.horizontal, Spacing.xxs)

            HStack(spacing: Spacing.sm) {
                if let storyID = place.storyID {
                    Button("Read the story") { router.open(.story(storyID)) }
                        .buttonStyle(.primary)
                }
                Button {
                    router.open(.map(focus: place.cover.id, site: place.storyID))
                } label: {
                    Label("Map", systemImage: "map")
                }
                .buttonStyle(.secondary)
            }
        }
        .padding(Spacing.sm)
        .glassCard(glow: place.storyID.flatMap { MockData.story($0)?.artwork })
    }
}

// MARK: - Pieces

/// Places / All photos, as a glass segmented control.
private struct ModeSwitch: View {
    @Binding var selection: PhotoGalleryView.Mode
    @Namespace private var lens

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PhotoGalleryView.Mode.allCases) { mode in
                let isSelected = mode == selection
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { selection = mode }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? Palette.onAccent : Palette.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if isSelected {
                                Capsule().fill(Palette.accent)
                                    .matchedGeometryEffect(id: "lens", in: lens)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .glassSurface(in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A place as an album: cover, two more photos, and a glass caption — curved edges.
private struct AlbumCard: View {
    let place: VisitedPlace

    var body: some View {
        let extras = Array(place.photos.dropFirst().prefix(2))

        VStack(spacing: 3) {
            // Same overall height with or without the strip, so the grid stays even.
            SitePhotoImage(photo: place.cover)
                .frame(maxWidth: .infinity)
                .frame(height: extras.isEmpty ? 217 : 150)
                .clipped()
            if !extras.isEmpty {
                HStack(spacing: 3) {
                    ForEach(extras) { photo in
                        SitePhotoImage(photo: photo)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .clipped()
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.cardInner - 6, style: .continuous))
        .overlay(alignment: .topTrailing) {
            GlassPill { Text("\(place.photos.count)").monospacedDigit() }
                .padding(Spacing.xs)
        }
        .safeAreaInset(edge: .bottom, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(place.lastVisit.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.xxs)
        }
        .padding(Spacing.xs)
        .glassCard(cornerRadius: Radius.cardInner)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(place.name), \(place.photos.count) photos")
        .accessibilityHint("Opens the album")
    }
}

/// Three-across grid of rounded photo tiles.
private struct PhotoGrid: View {
    let photos: [SitePhoto]
    var onOpen: (SitePhoto) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(photos) { photo in
                Button { onOpen(photo) } label: {
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay { SitePhotoImage(photo: photo) }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            Image(systemName: photo.isLocationApproximate ? "mappin" : "location.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                                .padding(5)
                                .glassSurface(in: Circle())
                                .padding(5)
                                .accessibilityHidden(true)
                        }
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Photo at \(photo.placeName), \(photo.date.formatted(date: .abbreviated, time: .shortened))")
            }
        }
    }
}

#Preview("Gallery") {
    NavigationStack { PhotoGalleryView().appDestinations() }
        .previewEnvironment()
}

#Preview("Album") {
    NavigationStack { PlaceAlbumView(placeID: "parthenon").appDestinations() }
        .previewEnvironment()
}
