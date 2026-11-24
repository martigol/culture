//
//  PhotoViewer.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import SwiftUI

/// What to show in the full-screen viewer: a set of photos (swipeable) and where to start.
struct PhotoViewerItem: Identifiable {
    let id = UUID()
    let photoIDs: [SitePhoto.ID]
    let start: SitePhoto.ID

    init(photos: [SitePhoto], start: SitePhoto? = nil) {
        photoIDs = photos.map(\.id)
        self.start = start?.id ?? photos.first?.id ?? UUID()
    }
}

/// Full-screen photo viewer (opened from a map marker, the gallery or a story):
/// swipe between photos, see where and when each was taken, open its story.
struct PhotoViewer: View {
    let item: PhotoViewerItem
    /// Nil hides "Read the story" (e.g. when already in that story).
    var onOpenStory: ((Story.ID) -> Void)?
    /// Nil hides "Show on map" (e.g. when opened from the map).
    var onShowOnMap: ((SitePhoto) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(PhotoStore.self) private var store
    @State private var selection: SitePhoto.ID? = nil
    @State private var confirmDelete = false

    private var photos: [SitePhoto] { item.photoIDs.compactMap(store.photo(id:)) }
    private var current: SitePhoto? { photos.first { $0.id == selection } ?? photos.first }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(photos) { photo in
                    SitePhotoImage(photo: photo, full: true, contentMode: .fit)
                        .ignoresSafeArea()
                        .tag(Optional(photo.id))
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                if let current { infoPanel(current) }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { if selection == nil { selection = item.start } }
        .onChange(of: photos.count) { _, count in
            if count == 0 { dismiss() }
            else if current?.id != selection { selection = photos.first?.id }
        }
        .confirmationDialog("Delete this photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Photo", role: .destructive, action: deleteCurrent)
        } message: {
            Text("It will be removed from your map and gallery. This can't be undone.")
        }
        .statusBarHidden()
    }

    private var topBar: some View {
        HStack {
            CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
            Spacer()
            if photos.count > 1, let index = photos.firstIndex(where: { $0.id == current?.id }) {
                Text("\(index + 1) of \(photos.count)")
                    .textStyle(.label)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, Spacing.sm)
                    .frame(minHeight: 28)
                    .background(Color.black.opacity(0.45), in: Capsule())
            }
            Spacer()
            Menu {
                if let current {
                    ShareLink(item: store.imageURL(for: current)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete Photo", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .light))
                    .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                    .background(Color.black.opacity(0.35), in: Circle())
                    .overlay(Circle().strokeBorder(Palette.ink.opacity(0.3), lineWidth: 0.75))
            }
            .accessibilityLabel("More")
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.xs)
    }

    private func infoPanel(_ photo: SitePhoto) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(photo.placeName)
                        .textStyle(.title)
                        .foregroundStyle(Palette.ink)
                    Text(subtitle(photo))
                        .textStyle(.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                    Label(photo.isLocationApproximate ? "Pinned to the site" : photo.location.formatted,
                          systemImage: "mappin.and.ellipse")
                        .textStyle(.label)
                        .foregroundStyle(Palette.inkTertiary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: Spacing.sm) {
                if let storyID = photo.storyID, let onOpenStory {
                    Button("Read the story") { onOpenStory(storyID) }
                        .buttonStyle(.primary)
                }
                if let onShowOnMap {
                    Button("Show on map") { onShowOnMap(photo) }
                        .buttonStyle(.secondary)
                }
            }
        }
        .padding(Spacing.screen)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.75), .black.opacity(0.9)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .animation(Motion.smooth, value: photo.id)
    }

    private func subtitle(_ photo: SitePhoto) -> String {
        let date = photo.date.formatted(date: .abbreviated, time: .shortened)
        return photo.region.isEmpty ? date : "\(photo.region) · \(date)"
    }

    private func deleteCurrent() {
        guard let current else { return }
        let remaining = photos.filter { $0.id != current.id }
        let index = photos.firstIndex(of: current) ?? 0
        selection = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)].id
        store.remove(current.id)
    }
}

#Preview {
    let store = PhotoStore.preview
    return PhotoViewer(item: PhotoViewerItem(photos: store.photos), onOpenStory: { _ in }, onShowOnMap: { _ in })
        .environment(store)
        .previewEnvironment()
}
