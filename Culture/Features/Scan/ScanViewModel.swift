import SwiftUI
import CoreLocation
import UIKit
import Observation

/// What the shutter does: identify a site (Scan) or just take a photo (Photo).
enum CaptureMode: String, CaseIterable, Identifiable {
    case scan, photo
    var id: String { rawValue }

    var title: String {
        switch self {
        case .scan: "Scan"
        case .photo: "Photo"
        }
    }
}

@Observable
@MainActor
final class ScanViewModel {
    enum Phase: Equatable {
        case aiming
        case recognizing
        case recognized(Story)
        case failed
    }

    var mode: CaptureMode = .scan
    var phase: Phase = .aiming
    var isFlashOn = false
    /// What Vision saw when nothing matched, e.g. "Looks like: Sculpture, Marble".
    var failureHint: String?
    /// The photo from the last successful scan, pinned to the user's map.
    var pinnedPhoto: SitePhoto?

    // Photo mode
    private(set) var isTakingPhoto = false
    /// Bumped on every shutter press (drives the flash animation and haptic).
    private(set) var shutterCount = 0
    /// Short confirmation or problem after a photo, e.g. "Pinned at The Parthenon".
    var photoMessage: String?

    /// A photo is filed under a story when taken within this distance of its site.
    static let siteRadius: CLLocationDistance = 5_000

    /// Takes a photo and pins it to the map where it was taken, filed under the
    /// nearest historical site (if one is close). No recognition.
    func takePhoto(camera: CameraController?, photos: PhotoStore, location: LocationProvider?, sites: [Story]) async {
        guard !isTakingPhoto else { return }
        isTakingPhoto = true
        defer { isTakingPhoto = false }
        shutterCount += 1
        photoMessage = nil

        let fixTask = Task { await location?.currentLocation() }
        var data = await camera?.capturePhoto(flash: isFlashOn)
        let fix = await fixTask.value
        var point = fix.map { GeoPoint($0.coordinate) }
        var site = point.flatMap { Self.nearestSite(to: $0, in: sites) }
        var approximate = false

        #if targetEnvironment(simulator)
        if data == nil {
            // No camera: use a story's image, pinned at its site (the Simulator's GPS is elsewhere).
            let story = site ?? sites.randomElement()
            data = story.flatMap { UIImage(named: $0.artwork.imageName)?.jpegData(compressionQuality: 0.85) }
            site = story
            point = story?.location
            approximate = true
        }
        #endif

        guard let data else {
            photoMessage = "Couldn't take the photo."
            return
        }
        guard let point else {
            photoMessage = "Turn on Location to pin photos to your map."
            return
        }
        guard await photos.add(imageData: data, at: point, approximate: approximate, story: site) != nil else {
            photoMessage = "Couldn't save the photo."
            return
        }
        photoMessage = site.map { "Pinned at \($0.title)" } ?? "Pinned to your map"
    }

    /// The closest story site within `siteRadius`, if any.
    static func nearestSite(to point: GeoPoint, in sites: [Story]) -> Story? {
        sites
            .map { (story: $0, distance: point.distance(to: $0.location)) }
            .filter { $0.distance <= siteRadius }
            .min { $0.distance < $1.distance }?
            .story
    }

    /// Takes a still from `camera` (if running) and identifies it. On a match the
    /// still is saved to `photos`, pinned where it was taken (GPS), or to the
    /// recognised site when no fix is available.
    /// Without a camera (Simulator, previews) the scanner gets `nil` data.
    func capture(using scanner: any ScanRecognizing, camera: CameraController?,
                 photos: PhotoStore? = nil, location: LocationProvider? = nil) async {
        guard phase == .aiming || phase == .failed else { return }
        phase = .recognizing
        failureHint = nil
        pinnedPhoto = nil
        do {
            let photo = await camera?.capturePhoto()
            // Ask for a fix while recognition runs; it's only used on a match.
            let fix = Task { await location?.currentLocation() }
            let story: Story
            do {
                story = try await scanner.recognize(imageData: photo)
            } catch {
                fix.cancel()
                throw error
            }
            phase = .recognized(story)
            Log.scan.info("Recognition succeeded")
            if let photos {
                if let photo {
                    let here = await fix.value
                    await pin(photo, of: story, at: here, in: photos)
                } else {
                    // No camera (Simulator): pin the sample image to the site itself,
                    // since the Simulator's GPS is usually somewhere else entirely.
                    fix.cancel()
                    await pin(Self.simulatedPhoto(for: story), of: story, at: nil, in: photos)
                }
            }
        } catch is CancellationError {
            phase = .aiming
        } catch ScanError.noMatch(let labels) {
            failureHint = labels.isEmpty ? nil : "Looks like: \(labels.joined(separator: ", "))"
            phase = .failed
        } catch {
            Log.scan.error("Recognition failed: \(error.localizedDescription)")
            phase = .failed
        }
    }

    private func pin(_ data: Data?, of story: Story, at fix: CLLocation?, in photos: PhotoStore) async {
        guard let data else { return }
        let point = fix.map { GeoPoint($0.coordinate) } ?? story.location
        let saved = await photos.add(imageData: data, at: point, approximate: fix == nil, story: story)
        // The sheet may have been dismissed (rescan) while saving.
        if case .recognized(let shown) = phase, shown.id == story.id { pinnedPhoto = saved }
    }

    /// In the Simulator there's no camera: pin the story's own image so the
    /// map and gallery can be exercised. Real devices always use the capture.
    private static func simulatedPhoto(for story: Story) -> Data? {
        #if targetEnvironment(simulator)
        return UIImage(named: story.artwork.imageName)?.jpegData(compressionQuality: 0.85)
        #else
        return nil
        #endif
    }

    func reset() {
        phase = .aiming
        failureHint = nil
        pinnedPhoto = nil
    }
}
