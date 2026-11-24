//
//  PhotoImageLoader.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import SwiftUI
import UIKit

/// Decodes site photos off the main thread, with an in-memory cache
/// (thumbnails are reused by map markers, grids and strips).
enum PhotoImageLoader {
    nonisolated(unsafe) private static let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 200
        return cache
    }()

    static func cached(_ url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }

    static func image(at url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
            return image.preparingForDisplay() ?? image
        }.value
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }

    static func evict(_ url: URL) { cache.removeObject(forKey: url as NSURL) }
}

/// A site photo, filled to its frame. Loads the thumbnail unless `full` is set.
struct SitePhotoImage: View {
    let photo: SitePhoto
    var full = false
    var contentMode: ContentMode = .fill

    @Environment(PhotoStore.self) private var store
    @State private var loaded: (url: URL, image: UIImage)? = nil

    var body: some View {
        let url = store.imageURL(for: photo, thumbnail: !full)
        Color.clear
            .overlay {
                if let image = loaded.flatMap({ $0.url == url ? $0.image : nil }) ?? PhotoImageLoader.cached(url) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
                } else {
                    Palette.surfaceRaised
                }
            }
            .clipped()
            .task(id: url) {
                if let image = await PhotoImageLoader.image(at: url) { loaded = (url, image) }
            }
            .accessibilityLabel("Photo at \(photo.placeName)")
    }
}

#Preview {
    let store = PhotoStore.preview
    return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
        ForEach(store.photos) { photo in
            SitePhotoImage(photo: photo).aspectRatio(1, contentMode: .fill)
        }
    }
    .padding(Spacing.screen)
    .environment(store)
    .previewEnvironment()
}
