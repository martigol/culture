//
//  Highlight.swift
//  Culture
//
//  Created by Mario Martinelli on 23/11/2026.
//

import SwiftUI
import UIKit

/// A passage the reader marked in a story's body, optionally with a note.
///
/// The range is stored as UTF-16 offsets into `Story.body` (what UIKit text
/// views use). `text` keeps a copy of the passage so the highlight can be
/// re-anchored if the backend edits the story (see `HighlightStore.reconcile`).
struct Highlight: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let storyID: Story.ID
    var location: Int
    var length: Int
    var text: String
    var color: HighlightColor
    var note: String?
    let createdAt: Date
    var updatedAt: Date

    var range: NSRange {
        get { NSRange(location: location, length: length) }
        set { location = newValue.location; length = newValue.length }
    }

    var hasNote: Bool { !(note ?? "").isEmpty }
}

/// Highlighter inks. Deliberately muted (pigment on old paper) so they sit
/// inside the monochrome "Engraving" palette instead of fighting it.
/// These are the only hues in the app, and only for reader highlights.
enum HighlightColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case ochre, olive, slate, rose

    var id: String { rawValue }

    var name: String {
        switch self {
        case .ochre: "Ochre"
        case .olive: "Olive"
        case .slate: "Slate"
        case .rose: "Rose"
        }
    }

    private var hex: UInt32 {
        switch self {
        case .ochre: 0xC9A35B
        case .olive: 0xA3AD6B
        case .slate: 0x7C93AD
        case .rose: 0xC38590
        }
    }

    /// Solid swatch (palette buttons, list markers).
    var swatch: Color { Color(hex: hex) }

    /// Translucent wash drawn behind highlighted text.
    var wash: UIColor { UIColor(swatch).withAlphaComponent(0.34) }
}
