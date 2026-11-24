//
//  MapComponents.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import MapKit
import SwiftUI

// MARK: - Style

extension MapStyle {
    /// Quiet dark basemap so the bone markers carry the screen (brand is monochrome).
    static var engraving: MapStyle {
        .standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false)
    }
}

// MARK: - Clustering

/// Photos close enough on screen to share one marker at the current zoom.
struct PhotoCluster: Identifiable, Equatable {
    let id: String
    let photos: [SitePhoto]
    let center: GeoPoint

    var cover: SitePhoto { photos[0] }
    var isSingle: Bool { photos.count == 1 }

    /// `true` when the photos sit practically on one spot (~150 m), so zooming
    /// in won't separate them: tapping should open them instead.
    var isTight: Bool {
        let lats = photos.map(\.location.latitude), lons = photos.map(\.location.longitude)
        return (lats.max()! - lats.min()!) < 0.0015 && (lons.max()! - lons.min()!) < 0.0015
    }
}

enum PhotoClusterer {
    /// Greedy screen-space clustering (MapKit for SwiftUI has none on iOS 17).
    /// A photo joins the first cluster whose seed is within about one marker
    /// width at the current zoom; otherwise it starts a new one.
    /// `photos` should be newest first, so each cluster's cover is its latest photo.
    static func clusters(_ photos: [SitePhoto], in span: MKCoordinateSpan) -> [PhotoCluster] {
        // ~64 pt marker on a ~390 × 800 pt map.
        let latThreshold = max(span.latitudeDelta * 0.08, 0.00002)
        let lonThreshold = max(span.longitudeDelta * 0.16, 0.00002)

        var seeds: [GeoPoint] = []
        var groups: [[SitePhoto]] = []
        for photo in photos {
            let p = photo.location
            if let i = seeds.firstIndex(where: {
                abs($0.latitude - p.latitude) < latThreshold && abs($0.longitude - p.longitude) < lonThreshold
            }) {
                groups[i].append(photo)
            } else {
                seeds.append(p)
                groups.append([photo])
            }
        }
        return groups.map { group in
            let lat = group.map(\.location.latitude).reduce(0, +) / Double(group.count)
            let lon = group.map(\.location.longitude).reduce(0, +) / Double(group.count)
            return PhotoCluster(id: "\(group[0].id.uuidString)-\(group.count)", photos: group, center: GeoPoint(lat, lon))
        }
    }
}

// MARK: - Markers

/// A snapped photo on the map: bone-framed print with a pointer at its spot.
struct PhotoMarker: View {
    let photo: SitePhoto
    var size: CGFloat = 56
    var isSelected = false

    var body: some View {
        VStack(spacing: 0) {
            SitePhotoImage(photo: photo)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                        .strokeBorder(Palette.ink, lineWidth: 2)
                )
            MarkerPointer().fill(Palette.ink).frame(width: 12, height: 7)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.55), radius: 6, y: 3)
        .scaleEffect(isSelected ? 1.18 : 1, anchor: .bottom)
        .animation(Motion.spring, value: isSelected)
    }
}

/// Several photos stacked like prints, with a count.
struct ClusterMarker: View {
    let cluster: PhotoCluster
    var size: CGFloat = 56

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                ForEach(Array(cluster.photos.prefix(3).enumerated().reversed()), id: \.element.id) { index, photo in
                    SitePhotoImage(photo: photo)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                .strokeBorder(Palette.ink, lineWidth: index == 0 ? 2 : 1)
                        )
                        .brightness(index == 0 ? 0 : -0.25)
                        .rotationEffect(.degrees(Double(index) * (index.isMultiple(of: 2) ? -7 : 7)))
                        .offset(x: CGFloat(index) * 3, y: CGFloat(-index) * 2)
                }
            }
            Text("\(cluster.photos.count)")
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Palette.onAccent)
                .padding(.horizontal, 6)
                .frame(minWidth: 22, minHeight: 22)
                .background(Palette.ink, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.background, lineWidth: 1.5))
                .offset(x: 9, y: -9)
        }
        .padding(.bottom, 7) // same anchor height as PhotoMarker's pointer
        .compositingGroup()
        .shadow(color: .black.opacity(0.55), radius: 6, y: 3)
        .accessibilityElement()
        .accessibilityLabel("\(cluster.photos.count) photos at \(cluster.cover.placeName)")
    }
}

/// A story site the user hasn't photographed yet: small hollow diamond.
struct SiteDot: View {
    let title: String
    var showsTitle: Bool

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Rectangle()
                .strokeBorder(Palette.ink.opacity(0.8), lineWidth: 1)
                .background(Palette.background.opacity(0.7))
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(45))
                .frame(width: HitTarget.minimum, height: 20)
            if showsTitle {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Palette.inkSecondary)
                    .shadow(color: .black, radius: 2)
                    .fixedSize()
            }
        }
    }
}

/// The story's own site: a bone pin with a dark core.
struct SitePin: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Palette.ink).frame(width: 26, height: 26)
                Circle().fill(Palette.background).frame(width: 9, height: 9)
            }
            MarkerPointer().fill(Palette.ink).frame(width: 10, height: 7)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
        .accessibilityHidden(true)
    }
}

struct MarkerPointer: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Map entry card

/// Entry card for the map (Library, gallery header): the latest places as a
/// strip of prints. Deliberately not a map: the app has one, `JourneyMapView`.
struct PinnedPlacesPreview: View {
    var height: CGFloat = 180

    @Environment(PhotoStore.self) private var store

    var body: some View {
        let covers = store.places.prefix(4).map(\.cover)

        HStack(spacing: 2) {
            if covers.isEmpty {
                ZStack {
                    Palette.surface
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: "map")
                            .font(.system(size: 26, weight: .ultraLight))
                        Text("Your photos get pinned here")
                            .textStyle(.footnote)
                    }
                    .foregroundStyle(Palette.inkSecondary)
                }
            } else {
                ForEach(covers) { photo in
                    SitePhotoImage(photo: photo)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            }
        }
        .frame(height: height)
        .overlay(alignment: .bottomLeading) {
            if !covers.isEmpty {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(7)
                    .background(Color.black.opacity(0.5), in: Circle())
                    .padding(Spacing.xs)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 0.75)
        )
        .accessibilityHidden(true)
    }
}

#Preview("Markers") {
    let store = PhotoStore.preview
    let cluster = PhotoClusterer.clusters(store.photos, in: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10))
        .max { $0.photos.count < $1.photos.count }!
    return HStack(alignment: .bottom, spacing: Spacing.xl) {
        PhotoMarker(photo: store.photos[0])
        PhotoMarker(photo: store.photos[1], isSelected: true)
        ClusterMarker(cluster: cluster)
        SitePin()
        SiteDot(title: "Olympia", showsTitle: true)
    }
    .padding(Spacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Palette.background)
    .environment(store)
    .previewEnvironment()
}

#Preview("Map entry card") {
    PinnedPlacesPreview(height: 220)
        .padding(Spacing.screen)
        .frame(maxHeight: .infinity)
        .screenBackground()
        .previewEnvironment()
}
