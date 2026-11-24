import SwiftUI

/// Dependency container. Swap mock services for real ones here — features
/// read them from the environment and never instantiate services directly.
struct AppEnvironment {
    var stories: any StoryProviding
    var scanner: any ScanRecognizing
    var recommender: any Recommending
    var keychain: KeychainStore

    /// Everything simulated: fixed latency, random scan results.
    static let mock = AppEnvironment(
        stories: MockStoryService(),
        scanner: MockScanService(),
        recommender: ContentBasedRecommender(),
        keychain: KeychainStore()
    )

    /// On-device recognition (camera + Vision / Core ML). Content still comes
    /// from `MockStoryService` until the backend lands.
    static let live: AppEnvironment = {
        let stories = MockStoryService()
        return AppEnvironment(
            stories: stories,
            scanner: VisionScanService(stories: stories),
            recommender: ContentBasedRecommender(),
            keychain: KeychainStore()
        )
    }()

    /// `.live` on a real device, `.mock` in the Simulator (it has no camera).
    static var current: AppEnvironment {
        #if targetEnvironment(simulator)
        return .mock
        #else
        return .live
        #endif
    }
}

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppEnvironment.mock
}

extension EnvironmentValues {
    var services: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
