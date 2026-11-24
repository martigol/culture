//
//  PhotoStore.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import Foundation
import ImageIO
import Observation
import UIKit
import UniformTypeIdentifiers

/// The user's site photos: JPEGs (+ thumbnails) in Application Support, and a
/// small JSON index with where/when each was taken.
///
/// SECURITY/PRIVACY: photos and their coordinates never leave the device.
/// Files use complete-until-first-unlock protection; EXIF (incl. GPS) is
/// stripped when the image is re-encoded, so a shared photo carries no location.
@Observable
@MainActor
final class PhotoStore {
    /// Newest first.
    private(set) var photos: [SitePhoto] = []

    let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("photos.json") }

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SitePhotos", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        photos = Self.readIndex(at: base.appendingPathComponent("photos.json"))
    }

    // MARK: Queries

    func photo(id: SitePhoto.ID) -> SitePhoto? { photos.first { $0.id == id } }

    func sitePhotos(for storyID: Story.ID) -> [SitePhoto] { photos.filter { $0.storyID == storyID } }

    func imageURL(for photo: SitePhoto, thumbnail: Bool = false) -> URL {
        directory.appendingPathComponent(thumbnail ? photo.thumbnailName : photo.fileName)
    }

    /// Places visited, one per story (or per spot for unmatched photos), newest first.
    var places: [VisitedPlace] {
        var order: [String] = []
        var groups: [String: [SitePhoto]] = [:]
        for photo in photos {
            let key = photo.storyID ?? photo.placeName
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(photo)
        }
        return order.compactMap { key in groups[key].map { VisitedPlace(id: key, photos: $0) } }
    }

    // MARK: Changes

    /// Saves a captured photo pinned to `location`. Image work happens off the main actor.
    @discardableResult
    func add(imageData: Data, at location: GeoPoint, approximate: Bool, story: Story?, date: Date = .now) async -> SitePhoto? {
        let photo = SitePhoto(
            id: UUID(), date: date, location: location, isLocationApproximate: approximate,
            storyID: story?.id, placeName: story?.title ?? "Unknown site", region: story?.region ?? ""
        )
        let full = imageURL(for: photo)
        let thumb = imageURL(for: photo, thumbnail: true)

        let saved = await Task.detached(priority: .userInitiated) {
            Self.writeJPEG(from: imageData, maxPixel: 2048, quality: 0.85, to: full)
                && Self.writeJPEG(from: imageData, maxPixel: 360, quality: 0.75, to: thumb)
        }.value

        guard saved else {
            Log.app.error("Couldn't save site photo")
            try? FileManager.default.removeItem(at: full)
            try? FileManager.default.removeItem(at: thumb)
            return nil
        }
        photos.insert(photo, at: 0)
        persist()
        return photo
    }

    func remove(_ id: SitePhoto.ID) {
        guard let photo = photo(id: id) else { return }
        photos.removeAll { $0.id == id }
        persist()
        for url in [imageURL(for: photo), imageURL(for: photo, thumbnail: true)] {
            PhotoImageLoader.evict(url)
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: Disk

    private func persist() {
        do {
            let data = try JSONEncoder.photos.encode(photos)
            try data.write(to: indexURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            Log.app.error("Couldn't save photo index: \(error.localizedDescription)")
        }
    }

    private static func readIndex(at url: URL) -> [SitePhoto] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder.photos.decode([SitePhoto].self, from: data)) ?? []
    }

    /// Downscales (baking in EXIF orientation) and re-encodes as JPEG, which drops metadata.
    nonisolated private static func writeJPEG(from data: Data, maxPixel: Int, quality: CGFloat, to url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: quality) else { return false }
        do {
            try jpeg.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }
}

/// All photos taken at one place.
struct VisitedPlace: Identifiable, Hashable {
    let id: String
    let photos: [SitePhoto]

    var cover: SitePhoto { photos[0] }
    var name: String { cover.placeName }
    var region: String { cover.region }
    var storyID: Story.ID? { cover.storyID }
    var lastVisit: Date { cover.date }
    var location: GeoPoint { cover.location }
}

private extension JSONEncoder {
    static let photos: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let photos: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

// MARK: - Sample photos (previews, Simulator)

extension PhotoStore {
    /// A store in a temp folder, seeded with sample photos for `#Preview`.
    static var preview: PhotoStore {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("PreviewPhotos-\(UUID().uuidString)")
        let store = PhotoStore(directory: dir)
        store.seedSamplesSynchronously()
        return store
    }

    /// Fills an empty store with the bundled story images, pinned around their
    /// sites, so the map and gallery can be tried without a camera.
    /// Debug: launch with `-seedPhotos YES`.
    func seedSamplesSynchronously() {
        guard photos.isEmpty else { return }
        // (story, offset in degrees from the site, days ago)
        let samples: [(String, Double, Double, Double)] = [
            ("parthenon", 0.0004, -0.0006, 2), ("parthenon", -0.0003, 0.0005, 2), ("parthenon", 0.0009, 0.0002, 9),
            ("sounion", 0.0002, 0.0003, 3), ("delphi", -0.0005, 0.0004, 5), ("charioteer", 0.0001, -0.0002, 5),
            ("mycenae", 0.0002, 0.0001, 6), ("agamemnon", -0.0003, 0.0004, 6), ("epidaurus", 0.0004, 0.0003, 7),
            ("knossos", 0.0003, -0.0004, 12),
        ]
        var seeded: [SitePhoto] = []
        for (id, dLat, dLon, daysAgo) in samples {
            guard let story = MockData.story(id),
                  let data = UIImage(named: story.artwork.imageName)?.jpegData(compressionQuality: 0.85) else { continue }
            let photo = SitePhoto(
                id: UUID(), date: .now.addingTimeInterval(-daysAgo * 86_400 - Double(seeded.count) * 600),
                location: GeoPoint(story.location.latitude + dLat, story.location.longitude + dLon),
                isLocationApproximate: false, storyID: story.id, placeName: story.title, region: story.region
            )
            guard Self.writeJPEG(from: data, maxPixel: 2048, quality: 0.85, to: imageURL(for: photo)),
                  Self.writeJPEG(from: data, maxPixel: 360, quality: 0.75, to: imageURL(for: photo, thumbnail: true))
            else { continue }
            seeded.append(photo)
        }
        photos = seeded.sorted { $0.date > $1.date }
        persist()
    }
}
