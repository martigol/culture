import SwiftUI
import UIKit

@main
struct CultureApp: App {
    @State private var router = Router()
    @State private var library = LibraryStore()
    @State private var highlights = HighlightStore()
    @State private var photos = PhotoStore()
    @State private var location = LocationProvider()
    @State private var permissions = PermissionsCenter()
    @State private var nearbyAlerts = NearbySiteAlerts()
    @State private var showsSplash = true
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Appearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(library)
                .environment(highlights)
                .environment(photos)
                .environment(location)
                .environment(permissions)
                .environment(nearbyAlerts)
                .environment(\.services, .current)
                // Launch animation over the app; it opens up to reveal it.
                .overlay {
                    if showsSplash { SplashView { showsSplash = false } }
                }
                // First launch: switch on what the app needs.
                .fullScreenCover(isPresented: onboardingBinding) {
                    PermissionsView { permissions.hasCompletedOnboarding = true }
                        .environment(permissions)
                        .environment(nearbyAlerts)
                        .environment(location)
                        .environment(\.services, .current)
                        .preferredColorScheme(.dark)
                }
                .task { await setUpNearbyAlerts() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await refreshNearbyAlerts() } }
                }
                .tint(Palette.accent)
                // Brand decision: dark-first cinematic look. Remove to follow system.
                .preferredColorScheme(.dark)
                .privacyShield()
                #if DEBUG
                .onAppear(perform: applyDebugLaunchRoute)
                #endif
        }
    }

    private var onboardingBinding: Binding<Bool> {
        // Waits for the splash to finish.
        Binding(get: { !permissions.hasCompletedOnboarding && !showsSplash },
                set: { if !$0 { permissions.hasCompletedOnboarding = true } })
    }

    /// Notification actions open the story or Apple Maps; alerts are (re)scheduled.
    private func setUpNearbyAlerts() async {
        nearbyAlerts.configure()
        nearbyAlerts.onOpenStory = { id in
            if router.isScanPresented {
                router.openAfterDismiss(.story(id), in: .home)
                router.isScanPresented = false
            } else {
                router.open(.story(id), in: .home)
            }
        }
        nearbyAlerts.onDirections = { id in
            guard let story = MockData.story(id), let url = story.location.appleMapsURL(name: story.title) else { return }
            UIApplication.shared.open(url)
        }
        await refreshNearbyAlerts()
    }

    private func refreshNearbyAlerts() async {
        await permissions.refresh()
        let sites = (try? await AppEnvironment.current.stories.allStories()) ?? MockData.stories
        await nearbyAlerts.refresh(sites: sites)
    }

    #if DEBUG
    /// QA / screenshot helper. Examples (Scheme ▸ Arguments, or simctl launch):
    ///   -debugTab library   -debugStory parthenon   -debugScan YES
    ///   -seedPhotos YES (sample pinned photos)   -debugMap YES
    private func applyDebugLaunchRoute() {
        let d = UserDefaults.standard
        switch d.string(forKey: "debugTab") {
        case "search": router.selectedTab = .search
        case "stories": router.selectedTab = .stories
        case "library": router.selectedTab = .library
        default: break
        }
        if let id = d.string(forKey: "debugStory") { router.open(.story(id)) }
        if d.bool(forKey: "debugScan") { router.presentScan() }
        if d.bool(forKey: "seedPhotos") { photos.seedSamplesSynchronously() }
        if d.bool(forKey: "debugMap") { router.open(.map(focus: nil), in: .library) }
    }
    #endif
}
