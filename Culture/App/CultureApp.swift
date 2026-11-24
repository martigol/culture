import SwiftUI

@main
struct CultureApp: App {
    @State private var router = Router()
    @State private var library = LibraryStore()
    @State private var highlights = HighlightStore()
    @State private var photos = PhotoStore()
    @State private var location = LocationProvider()

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
                .environment(\.services, .current)
                .tint(Palette.accent)
                // Brand decision: dark-first cinematic look. Remove to follow system.
                .preferredColorScheme(.dark)
                .privacyShield()
                #if DEBUG
                .onAppear(perform: applyDebugLaunchRoute)
                #endif
        }
    }

    #if DEBUG
    /// QA / screenshot helper. Examples (Scheme ▸ Arguments, or simctl launch):
    ///   -debugTab library   -debugStory parthenon   -debugScan YES
    ///   -seedPhotos YES (sample pinned photos)   -debugMap YES
    private func applyDebugLaunchRoute() {
        let d = UserDefaults.standard
        switch d.string(forKey: "debugTab") {
        case "gallery": router.selectedTab = .gallery
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
