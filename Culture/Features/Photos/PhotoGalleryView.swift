//
//  PhotoGalleryView.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import SwiftUI

/// Every photo snapped at a site, grouped by place, each group pinned on the map.
struct PhotoGalleryView: View {
    @Environment(PhotoStore.self) private var store
    @Environment(Router.self) private var router
    @State private var viewing: PhotoViewerItem? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        ScrollView {
            if store.photos.isEmpty {
                VStack(spacing: Spacing.lg) {
                    EmptyStateView(symbol: "photo.on.rectangle.angled", title: "No photos yet",
                                   message: "Photos you take while scanning a site appear here, pinned to where you took them.")
                    Button("Scan a site") { router.presentScan() }
                        .buttonStyle(.primary)
                        .padding(.horizontal, Spacing.screen)
                }
                .padding(.top, Spacing.xxl)
            } else {
                LazyVStack(alignment: .leading, spacing: Spacing.xl, pinnedViews: []) {
                    NavigationLink(value: Route.map(focus: nil)) {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            PinnedPlacesPreview(height: 120)
                            Label("Open your map", systemImage: "map")
                                .textStyle(.footnote)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                    .buttonStyle(.pressable)
                    .padding(.horizontal, Spacing.screen)

                    ForEach(store.places) { place in
                        section(place)
                    }
                }
                .padding(.top, Spacing.xs)
                .padding(.bottom, Spacing.section)
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
        .fullScreenCover(item: $viewing) { item in
            PhotoViewer(
                item: item,
                onOpenStory: { id in
                    viewing = nil
                    router.open(.story(id))
                },
                onShowOnMap: { photo in
                    viewing = nil
                    router.open(.map(focus: photo.id))
                }
            )
        }
    }

    private func section(_ place: VisitedPlace) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(place.name)
                        .textStyle(.headline)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(meta(place))
                        .textStyle(.label)
                        .foregroundStyle(Palette.inkTertiary)
                }
                Spacer()
                Button { router.open(.map(focus: place.cover.id)) } label: {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Palette.ink)
                        .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                }
                .accessibilityLabel("Show \(place.name) on the map")
            }
            .padding(.horizontal, Spacing.screen)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(place.photos) { photo in
                    Button { viewing = PhotoViewerItem(photos: place.photos, start: photo) } label: {
                        SitePhotoImage(photo: photo)
                            .aspectRatio(1, contentMode: .fill)
                            .overlay(alignment: .bottomLeading) {
                                Image(systemName: photo.isLocationApproximate ? "mappin" : "location.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Palette.ink)
                                    .padding(5)
                                    .background(Color.black.opacity(0.45), in: Circle())
                                    .padding(Spacing.xxs)
                                    .accessibilityHidden(true)
                            }
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Photo at \(place.name), \(photo.date.formatted(date: .abbreviated, time: .shortened))")
                }
            }
            .padding(.horizontal, Spacing.screen)
        }
    }

    private func meta(_ place: VisitedPlace) -> String {
        let count = "\(place.photos.count) \(place.photos.count == 1 ? "photo" : "photos")"
        let date = place.lastVisit.formatted(date: .abbreviated, time: .omitted)
        return [place.region, count, date].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack { PhotoGalleryView().appDestinations() }
        .previewEnvironment()
}
