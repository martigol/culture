import SwiftUI

/// Root tab bar. "Scan" is a tab for discoverability, but selecting it presents
/// the full-screen camera instead of switching tabs (camera is a modal task, HIG).
struct RootView: View {
    @Environment(Router.self) private var router
    @Namespace private var zoom

    var body: some View {
        @Bindable var router = router

        TabView(selection: tabSelection) {
            tab(.home) { HomeView() }
            tab(.discover) { DiscoverView() }
            Color.clear
                .tabItem { Label(AppTab.scan.title, systemImage: AppTab.scan.symbol) }
                .tag(AppTab.scan)
            tab(.stories) { StoriesView() }
            tab(.library) { LibraryView() }
        }
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
        }
        .environment(\.zoomNamespace, zoom)
        .tabItem { Label(tab.title, systemImage: tab.symbol) }
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
            switch route {
            case .story(let id):
                StoryDetailView(storyID: id).zoomDestination(id: id, in: zoom)
            case .library(let section):
                LibraryListView(section: section)
            case .collection(let id):
                CollectionView(collectionID: id)
            }
        }
    }
}

#Preview {
    RootView()
        .environment(Router())
        .environment(LibraryStore())
        .preferredColorScheme(.dark)
}
