//
//  JourneyMapView.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import CoreLocation
import MapKit
import SwiftUI

/// The app's one map, Snap Map style: every photo snapped at a historical
/// site, pinned where it was taken, plus every story site.
/// Zoomed out, nearby photos stack into one marker with a count; zoom in and
/// they split into individual photo markers. Tap a stack to zoom into it, tap
/// a photo to open it full screen, tap a site to see it and its nearest neighbours.
/// Opened with a `site` (swipe from a story), it centres on that site.
struct JourneyMapView: View {
    /// Photo to centre on when the map opens.
    var focus: SitePhoto.ID?
    /// Story site to centre on and select when the map opens.
    var site: Story.ID?

    @Environment(PhotoStore.self) private var store
    @Environment(LocationProvider.self) private var location
    @Environment(Router.self) private var router
    @Environment(\.services) private var services
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var position: MapCameraPosition = .automatic
    @State private var span = MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
    @State private var didPlaceCamera = false
    @State private var sites: [Story] = []
    @State private var viewing: PhotoViewerItem? = nil
    @State private var selectedPlace: VisitedPlace.ID? = nil
    @State private var selectedSiteID: Story.ID? = nil
    @State private var satellite = false
    @State private var storyAfterViewer: Story.ID?

    private var selectedSite: Story? { sites.first { $0.id == selectedSiteID } }

    var body: some View {
        let clusters = PhotoClusterer.clusters(store.photos, in: span)
        let visitedStoryIDs = Set(store.photos.compactMap(\.storyID))
        // Visited sites are shown by their photos; the selected one always gets a pin.
        let dots = sites.filter { !visitedStoryIDs.contains($0.id) && $0.id != selectedSiteID }

        Map(position: $position) {
            UserAnnotation()

            ForEach(dots) { story in
                Annotation(story.title, coordinate: story.location.coordinate) {
                    Button { select(story) } label: {
                        SiteDot(title: story.title, showsTitle: span.latitudeDelta < 2.5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(story.title), not visited yet")
                }
                .annotationTitles(.hidden)
            }

            ForEach(clusters) { cluster in
                Annotation(cluster.cover.placeName, coordinate: cluster.center.coordinate, anchor: .bottom) {
                    Button { tap(cluster) } label: {
                        if cluster.isSingle {
                            PhotoMarker(photo: cluster.cover, isSelected: cluster.cover.id == focus)
                        } else {
                            ClusterMarker(cluster: cluster)
                        }
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(cluster.isSingle
                                        ? "Photo at \(cluster.cover.placeName)"
                                        : "\(cluster.photos.count) photos at \(cluster.cover.placeName)")
                }
                .annotationTitles(.hidden)
            }

            // Drawn last so the selected site sits above photo markers.
            if let selectedSite {
                MapCircle(center: selectedSite.location.coordinate, radius: 1_200)
                    .foregroundStyle(Palette.ink.opacity(0.12))
                Annotation(selectedSite.title, coordinate: selectedSite.location.coordinate, anchor: .bottom) {
                    SitePin()
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(satellite ? .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll) : .engraving)
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapPitchToggle()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            withAnimation(reduceMotion ? nil : Motion.snappy) { span = context.region.span }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Group {
                if let selectedSite { siteCard(selectedSite) } else { bottomPanel }
            }
            .animation(Motion.snappy, value: selectedSiteID)
        }
        .sensoryFeedback(.selection, trigger: selectedSiteID)
        .navigationTitle(selectedSite?.title ?? "Your Map")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { satellite.toggle() } label: {
                    Image(systemName: satellite ? "map" : "globe.europe.africa").fontWeight(.light)
                }
                .accessibilityLabel(satellite ? "Show standard map" : "Show satellite map")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.photos) {
                    Image(systemName: "square.grid.2x2").fontWeight(.light)
                }
                .accessibilityLabel("All photos")
            }
        }
        .fullScreenCover(item: $viewing, onDismiss: {
            // Navigate only once the viewer has fully closed (see Router.openAfterDismiss).
            if let id = storyAfterViewer {
                storyAfterViewer = nil
                openStory(id)
            }
        }) { item in
            PhotoViewer(item: item, onOpenStory: { id in
                storyAfterViewer = id
                viewing = nil
            })
        }
        .task {
            sites = (try? await services.stories.allStories()) ?? MockData.stories
            placeCameraIfNeeded()
            await location.requestAuthorizationIfNeeded()
        }
    }

    // MARK: Selected site

    private func siteCard(_ story: Story) -> some View {
        let photos = store.sitePhotos(for: story.id)
        let nearby = nearest(to: story)

        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(story.title)
                        .textStyle(.title)
                        .foregroundStyle(Palette.ink)
                    Text([story.region, story.era].filter { !$0.isEmpty }.joined(separator: " · "))
                        .textStyle(.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                    if let away = distanceFromUser(to: story) {
                        Label(away, systemImage: "location")
                            .textStyle(.label)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
                Spacer(minLength: 0)
                Button { selectedSiteID = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Palette.ink)
                        .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                }
                .accessibilityLabel("Close site")
            }

            HStack(spacing: Spacing.sm) {
                Button(story.id == site ? "Back to the story" : "Read the story") { openStory(story.id) }
                    .buttonStyle(.primary)
                Button {
                    if let url = story.location.appleMapsURL(name: story.title) { openURL(url) }
                } label: {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                }
                .buttonStyle(.secondary)
                .accessibilityHint("Opens Apple Maps")
            }

            if !photos.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Your photos here · \(photos.count)")
                        .textStyle(.label)
                        .foregroundStyle(Palette.inkSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: Spacing.xs) {
                            ForEach(photos) { photo in
                                Button { viewing = PhotoViewerItem(photos: photos, start: photo) } label: {
                                    SitePhotoImage(photo: photo)
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: Radius.xs, style: .continuous))
                                }
                                .buttonStyle(.pressable)
                                .accessibilityLabel("Your photo, \(photo.date.formatted(date: .abbreviated, time: .shortened))")
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .scrollClipDisabled()
                }
            }

            if !nearby.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Nearest sites to visit")
                        .textStyle(.label)
                        .foregroundStyle(Palette.inkSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: Spacing.sm) {
                            ForEach(nearby, id: \.story.id) { item in
                                Button { select(item.story) } label: {
                                    NearbySiteChip(story: item.story, distance: item.distance,
                                                   photoCount: store.sitePhotos(for: item.story.id).count)
                                }
                                .buttonStyle(.pressable)
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .scrollClipDisabled()
                }
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.vertical, Spacing.md)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 0.5) }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    /// Other sites, closest to `story` first.
    private func nearest(to story: Story, limit: Int = 8) -> [(story: Story, distance: CLLocationDistance)] {
        sites
            .filter { $0.id != story.id }
            .map { (story: $0, distance: story.location.distance(to: $0.location)) }
            .sorted { $0.distance < $1.distance }
            .prefix(limit)
            .map { $0 }
    }

    private func distanceFromUser(to story: Story) -> String? {
        guard location.isAuthorized, let here = location.lastLocation else { return nil }
        let meters = GeoPoint(here.coordinate).distance(to: story.location)
        return meters < 150 ? "You're here" : "\(meters.awayLabel) from you"
    }

    /// The story this map was opened from is already underneath: go back to it.
    private func openStory(_ id: Story.ID) {
        if id == site { dismiss() } else { router.open(.story(id)) }
    }

    // MARK: Bottom panel

    @ViewBuilder
    private var bottomPanel: some View {
        if store.photos.isEmpty {
            emptyCard
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(summary)
                    .textStyle(.label)
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.horizontal, Spacing.screen)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Spacing.sm) {
                        ForEach(store.places) { place in
                            Button { fly(to: place) } label: {
                                PlaceChip(place: place, isSelected: selectedPlace == place.id)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }
                .contentMargins(.horizontal, Spacing.screen, for: .scrollContent)
            }
            .padding(.vertical, Spacing.md)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 0.5) }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("No photos pinned yet").textStyle(.title).foregroundStyle(Palette.ink)
            Text("Scan a temple, statue or relic. The photo lands here, right where you took it.")
                .textStyle(.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Scan a site") { router.presentScan() }
                .buttonStyle(.primary)
                .padding(.top, Spacing.xs)
        }
        .padding(Spacing.lg)
        .background(Palette.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.75))
        .padding(Spacing.md)
    }

    private var summary: String {
        let places = store.places.count, photos = store.photos.count
        return "\(places) \(places == 1 ? "place" : "places") · \(photos) \(photos == 1 ? "photo" : "photos")"
    }

    // MARK: Camera

    private func placeCameraIfNeeded() {
        guard !didPlaceCamera else { return }
        didPlaceCamera = true
        let region: MKCoordinateRegion?
        if let focus, let photo = store.photo(id: focus) {
            region = MKCoordinateRegion(center: photo.location.coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006))
        } else if let site, let story = sites.first(where: { $0.id == site }) {
            // The site and its two nearest neighbours, so there's somewhere to go next.
            selectedSiteID = story.id
            let points = [story.location] + nearest(to: story, limit: 2).map(\.story.location)
            region = MKCoordinateRegion.fitting(points, padding: 1.6, minimumSpan: 0.05)
        } else if !store.photos.isEmpty {
            region = MKCoordinateRegion.fitting(store.photos.map(\.location), padding: 1.4, minimumSpan: 0.05)
        } else {
            region = MKCoordinateRegion.fitting(sites.map(\.location), padding: 1.3)
        }
        guard let region else { return }
        span = region.span
        position = .region(region)
    }

    private func move(to region: MKCoordinateRegion) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.8)) { position = .region(region) }
    }

    /// Selects a site and centres on it, keeping roughly the current zoom.
    private func select(_ story: Story) {
        selectedPlace = nil
        withAnimation(Motion.snappy) { selectedSiteID = story.id }
        let delta = min(max(span.latitudeDelta, 0.02), 1.5)
        move(to: MKCoordinateRegion(center: story.location.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)))
    }

    /// Stacks zoom in until they split; a stack on one spot (or a single photo) opens.
    private func tap(_ cluster: PhotoCluster) {
        if cluster.isSingle || cluster.isTight {
            viewing = PhotoViewerItem(photos: cluster.photos)
        } else if let region = MKCoordinateRegion.fitting(cluster.photos.map(\.location), padding: 2.4, minimumSpan: 0.003) {
            move(to: region)
        }
    }

    private func fly(to place: VisitedPlace) {
        selectedPlace = place.id
        let region = MKCoordinateRegion.fitting(place.photos.map(\.location), padding: 3, minimumSpan: 0.006)
        if let region { move(to: region) }
    }
}

/// Visited place in the map's bottom strip.
private struct PlaceChip: View {
    let place: VisitedPlace
    var isSelected: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            SitePhotoImage(photo: place.cover)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .textStyle(.callout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text("\(place.photos.count) · \(place.lastVisit.formatted(.dateTime.day().month(.abbreviated)))")
                    .textStyle(.label)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkTertiary)
            }
            .padding(.trailing, Spacing.xs)
        }
        .padding(Spacing.xxs)
        .padding(.trailing, Spacing.xs)
        .frame(maxWidth: 230, alignment: .leading)
        .glassSurface(in: Capsule())
        .overlay(Capsule().strokeBorder(Palette.ink.opacity(isSelected ? 0.9 : 0), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(place.name), \(place.photos.count) photos")
        .accessibilityHint("Shows this place on the map")
    }
}

/// A nearby site in the selected-site card: plate, name, distance.
private struct NearbySiteChip: View {
    let story: Story
    let distance: CLLocationDistance
    var photoCount: Int

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ArtworkView(artwork: story.artwork)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(story.title)
                    .textStyle(.callout)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                HStack(spacing: Spacing.xxs) {
                    Text(distance.distanceLabel).monospacedDigit()
                    if photoCount > 0 {
                        Image(systemName: "photo").accessibilityHidden(true)
                        Text("\(photoCount)").monospacedDigit()
                    }
                }
                .textStyle(.label)
                .foregroundStyle(Palette.inkTertiary)
            }
            .padding(.trailing, Spacing.xs)
        }
        .padding(Spacing.xxs)
        .padding(.trailing, Spacing.xs)
        .frame(maxWidth: 230, alignment: .leading)
        .glassSurface(in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(story.title), \(distance.distanceLabel)\(photoCount > 0 ? ", \(photoCount) of your photos" : "")")
        .accessibilityHint("Shows this site on the map")
    }
}

#Preview("With photos") {
    NavigationStack { JourneyMapView().appDestinations() }
        .previewEnvironment()
}

#Preview("From a story") {
    NavigationStack { JourneyMapView(site: "parthenon").appDestinations() }
        .previewEnvironment()
}

#Preview("Empty") {
    // The inner `.environment` wins over the seeded store from `previewEnvironment()`.
    NavigationStack { JourneyMapView().appDestinations() }
        .environment(PhotoStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent("empty-\(UUID())")))
        .previewEnvironment()
}
