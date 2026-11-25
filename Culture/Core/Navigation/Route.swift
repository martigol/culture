import SwiftUI
import Observation

enum AppTab: Hashable, CaseIterable {
    case home, gallery, scan, stories, library

    var title: String {
        switch self {
        case .home: "Home"
        case .gallery: "Gallery"
        case .scan: "Scan"
        case .stories: "Stories"
        case .library: "Library"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .gallery: "photo.on.rectangle.angled"
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
    /// The app's one map (Snap Map style): every pinned photo and every site.
    /// Optionally centred on one photo, or on a story's site with its nearest neighbours.
    case map(focus: SitePhoto.ID? = nil, site: Story.ID? = nil)
    /// Every site photo, grouped by place.
    case photos
    /// One place's photos (a `VisitedPlace.ID`).
    case album(String)
    /// Search across stories and your photographed places.
    case search
    /// The game: every site to photograph, filled or still locked.
    case odyssey
}

enum LibrarySection: String, Hashable, CaseIterable, Identifiable {
    case saved, highlights, offline, history, collections
    var id: String { rawValue }

    var title: String {
        switch self {
        case .saved: "Saved Stories"
        case .highlights: "Highlights & Notes"
        case .offline: "Offline Stories"
        case .history: "Scan History"
        case .collections: "My Collections"
        }
    }

    var symbol: String {
        switch self {
        case .saved: "bookmark"
        case .highlights: "highlighter"
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
    var selectedTab: AppTab = .home {
        didSet { if selectedTab != oldValue { setTabBarCollapsed(false) } }
    }
    var isScanPresented = false
    var paths: [AppTab: [Route]] = [:]

    /// The tab bar shrinks to Home · Scan · Library while scrolling down.
    private(set) var isTabBarCollapsed = false

    /// Full-screen destinations with their own back button (the map) hide the tab bar.
    var isTabBarHidden: Bool {
        if case .map = paths[selectedTab]?.last { return true }
        return false
    }

    func setTabBarCollapsed(_ collapsed: Bool) {
        guard collapsed != isTabBarCollapsed else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { isTabBarCollapsed = collapsed }
    }

    func binding(for tab: AppTab) -> Binding<[Route]> {
        Binding(get: { self.paths[tab] ?? [] }, set: { self.paths[tab] = $0 })
    }

    func open(_ route: Route, in tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        selectedTab = target
        paths[target, default: []].append(route)
    }

    func presentScan() { isScanPresented = true }

    /// A push waiting for a full-screen cover to finish closing.
    @ObservationIgnored private var pending: (route: Route, tab: AppTab?)?

    /// Use from inside a full-screen cover (photo viewer, camera, storyline)
    /// that is closing: pushing *while* a cover dismisses can leave an
    /// invisible layer over the new screen so it stops responding to touch.
    /// The push runs from the cover's `onDismiss` via `openPending()`.
    func openAfterDismiss(_ route: Route, in tab: AppTab? = nil) {
        pending = (route, tab)
    }

    /// Runs the queued push, if any. Call from a cover's `onDismiss`.
    func openPending() {
        guard let pending else { return }
        self.pending = nil
        open(pending.route, in: pending.tab)
    }

    /// Theme requested from elsewhere (e.g. Discover); consumed by StoriesView.
    var pendingStoriesFilter: StoryCategory?

    func openStories(filteredBy category: StoryCategory) {
        pendingStoriesFilter = category
        paths[.stories] = []
        selectedTab = .stories
    }
}
