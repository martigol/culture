import Foundation
import Observation

/// User library: saved stories, offline downloads, scan history, collections.
///
/// Persists only non-sensitive identifiers to `UserDefaults`.
/// SECURITY: Anything user-identifying (tokens, account data) goes in
/// `KeychainStore`, never here.
@Observable
@MainActor
final class LibraryStore {
    private(set) var savedIDs: [Story.ID] = []
    private(set) var offlineIDs: [Story.ID] = []
    private(set) var scanHistory: [ScanRecord] = []
    /// Stories the reader opened, most recent first (recommendation signal).
    private(set) var readIDs: [Story.ID] = []
    private(set) var collections: [StoryCollection] = MockData.collections

    private let defaults: UserDefaults
    private enum Keys {
        static let saved = "library.saved"
        static let offline = "library.offline"
        static let read = "library.read"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        savedIDs = defaults.stringArray(forKey: Keys.saved) ?? MockData.defaultSaved
        offlineIDs = defaults.stringArray(forKey: Keys.offline) ?? MockData.defaultOffline
        readIDs = defaults.stringArray(forKey: Keys.read) ?? []
        scanHistory = MockData.scanHistory
    }

    func isSaved(_ id: Story.ID) -> Bool { savedIDs.contains(id) }

    func toggleSaved(_ id: Story.ID) {
        if let i = savedIDs.firstIndex(of: id) { savedIDs.remove(at: i) } else { savedIDs.insert(id, at: 0) }
        defaults.set(savedIDs, forKey: Keys.saved)
    }

    func isOffline(_ id: Story.ID) -> Bool { offlineIDs.contains(id) }

    func toggleOffline(_ id: Story.ID) {
        if let i = offlineIDs.firstIndex(of: id) { offlineIDs.remove(at: i) } else { offlineIDs.insert(id, at: 0) }
        defaults.set(offlineIDs, forKey: Keys.offline)
    }

    func recordScan(of id: Story.ID) {
        scanHistory.insert(ScanRecord(id: UUID(), storyID: id, date: .now), at: 0)
    }

    /// Remembers the last 50 stories opened (identifiers only).
    func recordRead(_ id: Story.ID) {
        guard readIDs.first != id else { return }
        readIDs.removeAll { $0 == id }
        readIDs.insert(id, at: 0)
        if readIDs.count > 50 { readIDs.removeLast(readIDs.count - 50) }
        defaults.set(readIDs, forKey: Keys.read)
    }
}
