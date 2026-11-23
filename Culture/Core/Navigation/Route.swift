import SwiftUI
import Observation

enum AppTab: Hashable, CaseIterable {
    case home, discover, scan, stories, library

    var title: String {
        switch self {
        case .home: "Home"
        case .discover: "Discover"
        case .scan: "Scan"
        case .stories: "Stories"
        case .library: "Library"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .discover: "sparkles"
        case .scan: "viewfinder"
        case .stories: "text.book.closed"
        case .library: "books.vertical"
        }
    }
}

/// Typed navigation destinations, pushed onto each tab's stack.
enum Route: Hashable {
    case story(Story.ID)
    case library(LibrarySection)
    case collection(StoryCollection.ID)
}

enum LibrarySection: String, Hashable, CaseIterable, Identifiable {
    case saved, offline, history, collections
    var id: String { rawValue }

    var title: String {
        switch self {
        case .saved: "Saved Stories"
        case .offline: "Offline Stories"
        case .history: "Scan History"
        case .collections: "My Collections"
        }
    }

    var symbol: String {
        switch self {
        case .saved: "bookmark"
        case .offline: "arrow.down.circle"
        case .history: "clock.arrow.circlepath"
        case .collections: "square.stack"
        }
    }
}

/// Owns tab selection and per-tab navigation stacks so any screen
/// (e.g. the Scan flow) can deep-link into a story.
@Observable
@MainActor
final class Router {
    var selectedTab: AppTab = .home
    var isScanPresented = false
    var paths: [AppTab: [Route]] = [:]

    func binding(for tab: AppTab) -> Binding<[Route]> {
        Binding(get: { self.paths[tab] ?? [] }, set: { self.paths[tab] = $0 })
    }

    func open(_ route: Route, in tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        selectedTab = target
        paths[target, default: []].append(route)
    }

    func presentScan() { isScanPresented = true }

    /// Theme requested from elsewhere (e.g. Discover); consumed by StoriesView.
    var pendingStoriesFilter: StoryCategory?

    func openStories(filteredBy category: StoryCategory) {
        pendingStoriesFilter = category
        paths[.stories] = []
        selectedTab = .stories
    }
}
