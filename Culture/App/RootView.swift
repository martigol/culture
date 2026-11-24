import SwiftUI

/// Root tabs with the custom Liquid Glass bar (`AppTabBar`) in place of the
/// system tab bar. "Scan" sits in the bar for discoverability, but opens the
/// full-screen camera instead of switching tabs (camera is a modal task, HIG).
struct RootView: View {
    @Environment(Router.self) private var router
    @Namespace private var zoom

    var body: some View {
        @Bindable var router = router

        TabView(selection: tabSelection) {
            tab(.home) { HomeView() }
            tab(.gallery) { PhotoGalleryView() }
            tab(.stories) { StoriesView() }
            tab(.library) { LibraryView() }
        }
        // Content scrolls under the bar; screens' own bottom bars sit above it.
        .safeAreaInset(edge: .bottom, spacing: 0) { AppTabBar() }
        .fullScreenCover(isPresented: $router.isScanPresented) {
            ScanView()
        }
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
                .toolbar(.hidden, for: .tabBar)
        }
        .environment(\.zoomNamespace, zoom)
        .tag(tab)
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
        }
    }
}

#Preview {
    RootView()
        .previewEnvironment()
}
