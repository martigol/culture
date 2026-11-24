import Foundation

/// Normalises free-text input (search, collection names) before it is used
/// in queries or sent to a server: trims, strips control characters and
/// caps length to avoid abuse / oversized payloads.
enum InputSanitizer {
    static func clean(_ input: String, maxLength: Int = 120) -> String {
        let scalars = input.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }
        let trimmed = String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(maxLength))
    }
}
