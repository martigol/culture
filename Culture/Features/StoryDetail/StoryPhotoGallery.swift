//
//  StoryPhotoGallery.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import SwiftUI

/// "Snapped here": every photo the user took at this story's site, as a grid.
/// The map itself lives behind a swipe (see `MapPullTab`).
struct StoryPhotoGallery: View {
    let story: Story
    var onOpenPhotos: (_ photos: [SitePhoto], _ start: SitePhoto) -> Void
    var onShowMap: () -> Void

    @Environment(PhotoStore.self) private var photoStore
    @Environment(LocationProvider.self) private var location
    @Environment(Router.self) private var router

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    private let maxShown = 9

    var body: some View {
        let photos = photoStore.sitePhotos(for: story.id)

        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Snapped here", actionTitle: "Map", action: onShowMap)

            VStack(alignment: .leading, spacing: Spacing.md) {
                siteLine(photos)
                if photos.isEmpty { emptyCard } else { grid(photos) }
            }
            .padding(.horizontal, Spacing.screen)
        }
    }

    private func siteLine(_ photos: [SitePhoto]) -> some View {
        let parts = [story.region, distance, photos.isEmpty ? nil : "\(photos.count) \(photos.count == 1 ? "photo" : "photos")"]
        return Label(parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
                     systemImage: "mappin.and.ellipse")
            .textStyle(.label)
            .foregroundStyle(Palette.inkSecondary)
    }

    private func grid(_ photos: [SitePhoto]) -> some View {
        let shown = Array(photos.prefix(maxShown))
        let overflow = photos.count - shown.count

        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(shown) { photo in
                Button { onOpenPhotos(photos, photo) } label: {
                    SitePhotoImage(photo: photo)
                        .aspectRatio(1, contentMode: .fill)
                        .overlay {
                            if overflow > 0, photo.id == shown.last?.id {
                                ZStack {
                                    Color.black.opacity(0.55)
                                    Text("+\(overflow)")
                                        .textStyle(.title)
                                        .monospacedDigit()
                                        .foregroundStyle(Palette.ink)
                                }
                            }
                        }
                        .overlay(alignment: .bottomLeading) {
                            Text(photo.date.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.45), in: Capsule())
                                .padding(Spacing.xxs)
                                .accessibilityHidden(true)
                        }
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Your photo, \(photo.date.formatted(date: .abbreviated, time: .shortened))")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Palette.ink)
                .accessibilityHidden(true)
            Text("No photos from this site yet")
                .textStyle(.headline)
                .foregroundStyle(Palette.ink)
            Text("Snap it when you visit. Each photo is pinned to the spot you took it, so you can find it again on your map.")
                .textStyle(.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Snap this site") { router.presentScan() }
                .buttonStyle(.secondary)
                .padding(.top, Spacing.xs)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 0.75)
        )
    }

    private var distance: String? {
        guard location.isAuthorized, let here = location.lastLocation else { return nil }
        let meters = GeoPoint(here.coordinate).distance(to: story.location)
        return meters < 150 ? "You're here" : meters.awayLabel
    }
}

/// Trailing-edge tab on a story: swipe left from the right edge (or tap) and
/// the map slides in, centred on the story's site.
struct MapPullTab: View {
    var action: () -> Void

    @State private var drag: CGFloat = 0
    @State private var armed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far left the finger must travel to open the map.
    private let threshold: CGFloat = 72

    var body: some View {
        ZStack(alignment: .trailing) {
            // Thin full-height strip so the swipe can start anywhere on the edge.
            Color.clear
                .frame(width: 20)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            tab
        }
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { value in
                    // Rubber-band: follows the finger, but only leftwards.
                    drag = min(0, value.translation.width) * 0.7
                    armed = value.translation.width < -threshold
                }
                .onEnded { value in
                    if value.translation.width < -threshold || value.predictedEndTranslation.width < -threshold * 2 {
                        action()
                    }
                    armed = false
                    withAnimation(reduceMotion ? nil : Motion.spring) { drag = 0 }
                }
        )
        .sensoryFeedback(.impact(weight: .light), trigger: armed) { _, isArmed in isArmed }
    }

    private var tab: some View {
        VStack(spacing: Spacing.xxs) {
            Image(systemName: "chevron.compact.left")
                .font(.system(size: 14, weight: .medium))
            Image(systemName: armed ? "map.fill" : "map")
                .font(.system(size: 14, weight: .light))
                .contentTransition(.symbolEffect(.replace))
        }
        .foregroundStyle(Palette.ink)
        .frame(width: 30 - drag, height: 76)
        .background(.ultraThinMaterial,
                    in: UnevenRoundedRectangle(topLeadingRadius: Radius.md, bottomLeadingRadius: Radius.md,
                                               style: .continuous))
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: Radius.md, bottomLeadingRadius: Radius.md, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.35), radius: 6, x: -2)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityElement()
        .accessibilityLabel("Show on map")
        .accessibilityHint("The site, nearby places to visit and your photos. You can also swipe left from the right edge.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }
}

#Preview("With your photos") {
    ScrollView {
        StoryPhotoGallery(story: MockData.story("parthenon")!, onOpenPhotos: { _, _ in }, onShowMap: {})
            .padding(.vertical, Spacing.xl)
    }
    .overlay(alignment: .trailing) { MapPullTab {} }
    .screenBackground()
    .previewEnvironment()
}

#Preview("No photos") {
    ScrollView {
        StoryPhotoGallery(story: MockData.story("olympia")!, onOpenPhotos: { _, _ in }, onShowMap: {})
            .padding(.vertical, Spacing.xl)
    }
    .screenBackground()
    .previewEnvironment()
}
