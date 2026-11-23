import SwiftUI

/// Dependency container. Swap mock services for real ones here — features
/// read them from the environment and never instantiate services directly.
struct AppEnvironment {
    var stories: any StoryProviding
    var scanner: any ScanRecognizing
    var keychain: KeychainStore

    static let mock = AppEnvironment(
        stories: MockStoryService(),
        scanner: MockScanService(),
        keychain: KeychainStore()
    )
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
