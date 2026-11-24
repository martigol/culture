//
//  SitePhoto.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import Foundation

/// A photo the user snapped while scanning a historical site, pinned to where
/// it was taken. The image itself lives on disk (see `PhotoStore`).
struct SitePhoto: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let date: Date
    /// Where the photo was taken (GPS), or the story's site when no fix was available.
    var location: GeoPoint
    /// `true` when `location` is the site's coordinate rather than a GPS fix.
    var isLocationApproximate: Bool
    /// The story the scan recognised.
    var storyID: Story.ID?
    /// Display name for the pin, e.g. "The Parthenon".
    var placeName: String
    /// Area under the name, e.g. "Athens".
    var region: String

    var fileName: String { "\(id.uuidString).jpg" }
    var thumbnailName: String { "\(id.uuidString)-thumb.jpg" }
}
