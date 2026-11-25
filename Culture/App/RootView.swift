import SwiftUI

/// Root tabs with the custom Liquid Glass bar (`AppTabBar`) in place of the
/// system tab bar. "Scan" sits in the bar for discoverability, but opens the
/// full-screen camera instead of switching tabs (camera is a modal task, HIG).
/// Search is the last tab and searches everything.
struct RootView: View {
    @Environment(Router.self) private var router
    @Environment(PhotoStore.self) private var photos
    @Namespace private var zoom
    /// A newly captured site whose celebration didn't get shown in the camera.
    @State private var celebrating: Story?

    var body: some View {
        @Bindable var router = router

        TabView(selection: tabSelection) {
            tab(.home) { HomeView() }
            tab(.stories) { StoriesView() }
            tab(.library) { LibraryView() }
            // Global search across the whole app; each tab also has its own scoped search.
            tab(.search) { SearchView() }
        }
        // The bar floats over the content; each screen reserves room for it
        // (`reservesTabBarSpace`) so its own bottom controls sit above it.
        .overlay(alignment: .bottom) {
            if !router.isTabBarHidden {
                AppTabBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: router.isTabBarHidden)
        .fullScreenCover(isPresented: $router.isScanPresented, onDismiss: {
            router.openPending()
            celebrateNewSite()
        }) {
            ScanView()
        }
        // Odyssey: celebrate a first photo at a site if the camera closed before it could.
        .overlay {
            if let celebrating {
                SiteCapturedCelebration(
                    story: celebrating,
                    onContinue: { withAnimation(Motion.smooth) { self.celebrating = nil } },
                    onOpenOdyssey: {
                        self.celebrating = nil
                        router.open(.odyssey)
                    }
                )
                .transition(.opacity)
            }
        }
        .onChange(of: photos.newlyCapturedSite) { celebrateNewSite() }
    }

    private func celebrateNewSite() {
        guard !router.isScanPresented, celebrating == nil,
              let id = photos.consumeNewlyCapturedSite(), let story = MockData.story(id) else { return }
        withAnimation(Motion.smooth) { celebrating = story }
    }

    /// Intercepts the Scan tab so it opens the modal instead of switching.
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { router.selectedTab },
            set: { newValue in
                if newValue == .scan { router.presentScan() } else { router.selectedTab = newValue }
            }
        )
    }

    private func tab<Content: View>(_ tab: AppTab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack(path: router.binding(for: tab)) {
            content()
                .appDestinations()
                .collapsesTabBarOnScroll()
                .reservesTabBarSpace()
                .toolbar(.hidden, for: .tabBar)
        }
        .modifier(TabEntrance(isActive: router.selectedTab == tab))
        .environment(\.zoomNamespace, zoom)
        .tag(tab)
    }
}

private extension Route {
    var isMap: Bool {
        if case .map = self { return true }
        return false
    }
}

/// The incoming tab fades in and settles up into place while the bar's
/// selection lens slides across (animated by `AppTabBar`'s switch).
private struct TabEntrance: ViewModifier {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .offset(y: isActive || reduceMotion ? 0 : 14)
            .scaleEffect(isActive || reduceMotion ? 1 : 0.985, anchor: .bottom)
    }
}

extension View {
    /// Registers every typed `Route` destination. Add new routes here.
    func appDestinations() -> some View { modifier(AppDestinations()) }
}

private struct AppDestinations: ViewModifier {
    @Environment(\.zoomNamespace) private var zoom

    func body(content: Content) -> some View {
        content.navigationDestination(for: Route.self) { route in
            destination(for: route)
                .collapsesTabBarOnScroll()
                // The map hides the tab bar (it has a back button), so nothing to reserve.
                .reservesTabBarSpace(!route.isMap)
                .toolbar(.hidden, for: .tabBar)
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .story(let id):
            StoryDetailView(storyID: id).zoomDestination(id: id, in: zoom)
        case .library(let section):
            LibraryListView(section: section)
        case .collection(let id):
            CollectionView(collectionID: id)
        case let .map(focus, site):
            JourneyMapView(focus: focus, site: site)
        case .photos:
            PhotoGalleryView()
        case .album(let id):
            PlaceAlbumView(placeID: id)
        case .odyssey:
            OdysseyView()
        }
    }
}

#Preview {
    RootView()
        .previewEnvironment()
}

/// Root with a screen already pushed, to check the tab bar against it.
private struct PushedRootPreview: View {
    let route: Route
    @Environment(Router.self) private var router

    var body: some View {
        RootView().onAppear { router.open(route, in: .home) }
    }
}

#Preview("Story open") {
    PushedRootPreview(route: .story("parthenon")).previewEnvironment()
}

#Preview("Map open (no tab bar)") {
    PushedRootPreview(route: .map(site: "parthenon")).previewEnvironment()
}
