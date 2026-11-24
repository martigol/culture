import SwiftUI

/// A curated story (article + narration) about a myth, place or artifact.
struct Story: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var subtitle: String
    var category: StoryCategory
    var region: String
    /// Where the story happens: the site, or the museum that holds the object.
    var location: GeoPoint
    var era: String
    var durationMinutes: Int
    var summary: String
    var body: String
    var audioDurationSeconds: Int
    var artwork: Artwork
    var isRecommended: Bool = false

    var durationLabel: String { "\(durationMinutes) min" }
}

enum StoryCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case myths, gods, places, artifacts, history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .myths: "Myths"
        case .gods: "Gods & Heroes"
        case .places: "Sacred Places"
        case .artifacts: "Artifacts"
        case .history: "History"
        }
    }

    /// Representative cover image for theme tiles.
    var coverImage: String {
        switch self {
        case .myths: "medusa"
        case .gods: "zeus"
        case .places: "delphi"
        case .artifacts: "agamemnon"
        case .history: "mycenae"
        }
    }
}

/// Story imagery. `imageName` = bundled asset (sample content);
/// `imageURL` = remote image from the backend (takes precedence when set).
struct Artwork: Hashable, Sendable {
    var imageName: String
    var credit: String
    var imageURL: URL? = nil
    /// Where the subject sits in the frame, so crops keep it visible.
    var focus: UnitPoint = .center
}

struct ScanRecord: Identifiable, Hashable, Sendable {
    let id: UUID
    let storyID: Story.ID
    let date: Date
}

struct StoryCollection: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var storyIDs: [Story.ID]
}
