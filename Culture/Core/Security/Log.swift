import OSLog

/// Unified logging. Interpolated values are `.private` by default in OSLog,
/// so user content is redacted in production logs. Only mark values
/// `privacy: .public` when they are guaranteed non-sensitive (e.g. enum cases).
/// Never use `print` for anything containing user data or tokens.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.culture.heritage"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let scan = Logger(subsystem: subsystem, category: "scan")
}
