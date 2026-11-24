import Foundation

/// Typed access to build-time configuration injected via `Config/*.xcconfig`
/// → `Config/Info.plist`. Keeps environment values out of source code.
enum AppConfig {
    static var apiBaseURL: URL {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
            let url = URL(string: raw),
            url.scheme == "https"           // SECURITY: refuse non-TLS endpoints
        else {
            preconditionFailure("APIBaseURL missing or not HTTPS — check Config/Shared.xcconfig")
        }
        return url
    }

    static var appVersion: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}
