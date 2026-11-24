//
//  HighlightStore.swift
//  Culture
//
//  Created by Mario Martinelli on 23/11/2026.
//

import Foundation
import Observation

/// Highlights grouped under one story (Library ▸ Highlights & Notes).
struct HighlightGroup: Identifiable, Hashable {
    let storyID: Story.ID
    let items: [Highlight]
    var id: Story.ID { storyID }
}

/// Reader highlights and notes.
///
/// SECURITY / PRIVACY: notes are personal writing, so they are not kept in
/// `UserDefaults`. They're stored as JSON in Application Support with
/// complete file protection (encrypted while the device is locked).
@Observable
@MainActor
final class HighlightStore {
    private(set) var highlights: [Highlight] = []

    /// Last ink the reader used. Reused by the "Highlight" edit-menu action.
    var lastColor: HighlightColor = .ochre

    nonisolated static let maxNoteLength = 2_000

    private let fileURL: URL?

    init(fileURL: URL? = HighlightStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    /// In-memory store (previews, tests). Nothing is written to disk.
    static func inMemory(_ seed: [Highlight] = []) -> HighlightStore {
        let store = HighlightStore(fileURL: nil)
        store.highlights = seed
        return store
    }

    nonisolated static var defaultFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Highlights.json")
    }

    // MARK: Queries

    func highlights(for storyID: Story.ID) -> [Highlight] {
        highlights.filter { $0.storyID == storyID }.sorted { $0.location < $1.location }
    }

    func highlight(id: Highlight.ID) -> Highlight? {
        highlights.first { $0.id == id }
    }

    /// Grouped by story, most recently edited story first.
    var groups: [HighlightGroup] {
        Dictionary(grouping: highlights, by: \.storyID)
            .map { HighlightGroup(storyID: $0.key, items: $0.value.sorted { $0.location < $1.location }) }
            .sorted { lhs, rhs in
                (lhs.items.map(\.updatedAt).max() ?? .distantPast) > (rhs.items.map(\.updatedAt).max() ?? .distantPast)
            }
    }

    /// Highlights per story: a reading-interest signal for recommendations.
    var countsByStory: [Story.ID: Int] {
        Dictionary(grouping: highlights, by: \.storyID).mapValues(\.count)
    }

    // MARK: Mutations

    /// Highlights `range` of `body`. Overlapping highlights in the same story
    /// are merged into one, and their notes are kept.
    @discardableResult
    func add(_ range: NSRange, in body: String, storyID: Story.ID, color: HighlightColor) -> Highlight? {
        let ns = body as NSString
        guard range.location != NSNotFound, range.length > 0, NSMaxRange(range) <= ns.length else { return nil }

        let overlapping = highlights.filter {
            $0.storyID == storyID && NSIntersectionRange($0.range, range).length > 0
        }
        var merged = range
        for existing in overlapping { merged = NSUnionRange(merged, existing.range) }
        let notes = overlapping.compactMap(\.note).filter { !$0.isEmpty }
        let now = Date.now

        let highlight = Highlight(
            id: overlapping.first?.id ?? UUID(),
            storyID: storyID,
            location: merged.location,
            length: merged.length,
            text: ns.substring(with: merged),
            color: color,
            note: notes.isEmpty ? nil : notes.joined(separator: "\n\n"),
            createdAt: overlapping.map(\.createdAt).min() ?? now,
            updatedAt: now
        )
        let replaced = Set(overlapping.map(\.id))
        highlights.removeAll { replaced.contains($0.id) }
        highlights.append(highlight)
        lastColor = color
        save()
        return highlight
    }

    func setColor(_ color: HighlightColor, for id: Highlight.ID) {
        lastColor = color
        update(id) { $0.color = color }
    }

    func setNote(_ note: String?, for id: Highlight.ID) {
        let cleaned = note.map(Self.cleanNote) ?? ""
        update(id) { $0.note = cleaned.isEmpty ? nil : cleaned }
    }

    func remove(_ id: Highlight.ID) {
        highlights.removeAll { $0.id == id }
        save()
    }

    /// Re-anchors a story's highlights after its body is (re)loaded. If the
    /// text moved, the highlight follows it; if it's gone, it's dropped.
    func reconcile(storyID: Story.ID, body: String) {
        let ns = body as NSString
        var changed = false
        highlights = highlights.compactMap { (h: Highlight) -> Highlight? in
            guard h.storyID == storyID else { return h }
            if NSMaxRange(h.range) <= ns.length, ns.substring(with: h.range) == h.text { return h }
            changed = true
            let found = ns.range(of: h.text)
            guard found.location != NSNotFound else { return nil }
            var moved = h
            moved.range = found
            return moved
        }
        if changed { save() }
    }

    // MARK: Private

    private func update(_ id: Highlight.ID, _ change: (inout Highlight) -> Void) {
        guard let i = highlights.firstIndex(where: { $0.id == id }) else { return }
        change(&highlights[i])
        highlights[i].updatedAt = .now
        save()
    }

    /// Like `InputSanitizer.clean`, but keeps line breaks (notes are multi-line).
    private static func cleanNote(_ input: String) -> String {
        let kept: Set<Unicode.Scalar> = ["\n", "\t"]
        let scalars = input.unicodeScalars.filter { kept.contains($0) || !CharacterSet.controlCharacters.contains($0) }
        let trimmed = String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(maxNoteLength))
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        do {
            highlights = try JSONDecoder().decode([Highlight].self, from: data)
        } catch {
            Log.app.error("Highlights decode failed: \(error.localizedDescription)")
        }
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(highlights)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            Log.app.error("Highlights save failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview data

extension HighlightStore {
    /// Sample highlights on "sounion" and "parthenon" for #Preview.
    static var preview: HighlightStore {
        func make(_ storyID: Story.ID, _ phrase: String, _ color: HighlightColor, note: String? = nil) -> Highlight? {
            guard let story = MockData.story(storyID) else { return nil }
            let range = (story.body as NSString).range(of: phrase)
            guard range.location != NSNotFound else { return nil }
            return Highlight(id: UUID(), storyID: storyID, location: range.location, length: range.length,
                             text: phrase, color: color, note: note, createdAt: .now, updatedAt: .now)
        }
        return .inMemory([
            make("sounion", "his ship would return under white sails", .ochre,
                 note: "So the Aegean is named after Theseus' father."),
            make("sounion", "the last sight of home for sailors leaving Attica", .slate),
            make("parthenon", "without a single truly straight line", .olive),
        ].compactMap { $0 })
    }
}
