import SwiftUI

/// Type system.
///
/// - **Zodiak** (Fontshare, classical serif) is the brand voice: display moments,
///   titles and ledes only.
/// - **SF Pro** (system) carries all reading text, labels and controls — per the
///   iOS HIG and for legibility. It follows Dynamic Type automatically.
///
/// Features must use `.textStyle(_:)` (font + tracking + leading + case in one
/// place) — never `Font.custom` / `.font(.system(size:))` directly.
///
/// | Style     | Face                     | Size | Use                              |
/// |-----------|--------------------------|------|----------------------------------|
/// | hero      | Zodiak Regular           | 42   | One per screen, brand statements |
/// | display   | Zodiak Regular           | 34   | Story titles on detail           |
/// | title     | Zodiak Regular           | 24   | Card titles (large)              |
/// | headline  | Zodiak Regular           | 19   | Card / row titles                |
/// | lede      | Zodiak Regular           | 20   | Intro paragraph, quotes          |
/// | italic    | Zodiak Italic            | 17   | Subtitles                        |
/// | section   | Zodiak Regular, caps     | 14   | Section titles (inscribed)       |
/// | body      | SF Pro Text · Body       | 17   | Reading text                     |
/// | callout   | SF Pro · Callout medium  | 16   | Controls, values                 |
/// | footnote  | SF Pro · Footnote        | 13   | Secondary info                   |
/// | label     | SF Pro · Caption semibold| 12   | Meta ("Myths · 6 min")           |
/// | button    | SF Pro · Subhead semibold| 15   | Button titles                    |
enum TextStyle {
    case hero, display, title, headline, lede, italic, section
    case body, callout, footnote, label, button

    struct Spec {
        let font: Font
        var tracking: CGFloat = 0
        var lineSpacing: CGFloat = 0
        var uppercase = false
    }

    private static func zodiak(_ face: String, _ size: CGFloat, _ relative: Font.TextStyle) -> Font {
        .custom(face, size: size, relativeTo: relative)
    }

    var spec: Spec {
        switch self {
        case .hero:     Spec(font: Self.zodiak("Zodiak-Regular", 42, .largeTitle), tracking: -1, lineSpacing: -2)
        case .display:  Spec(font: Self.zodiak("Zodiak-Regular", 34, .largeTitle), tracking: -0.6)
        case .title:    Spec(font: Self.zodiak("Zodiak-Regular", 24, .title2), tracking: -0.3)
        case .headline: Spec(font: Self.zodiak("Zodiak-Regular", 19, .headline), tracking: -0.1, lineSpacing: 1)
        case .lede:     Spec(font: Self.zodiak("Zodiak-Regular", 20, .title3), tracking: -0.1, lineSpacing: 6)
        case .italic:   Spec(font: Self.zodiak("Zodiak-Italic", 17, .subheadline))
        case .section:  Spec(font: Self.zodiak("Zodiak-Regular", 14, .footnote), tracking: 2.2, uppercase: true)
        case .body:     Spec(font: .body, lineSpacing: 6)
        case .callout:  Spec(font: .callout.weight(.medium))
        case .footnote: Spec(font: .footnote, lineSpacing: 2)
        case .label:    Spec(font: .caption.weight(.semibold))
        case .button:   Spec(font: .subheadline.weight(.semibold))
        }
    }

    var font: Font { spec.font }
}

extension View {
    /// Applies a complete text style: face, size (Dynamic Type), tracking,
    /// line spacing and case.
    func textStyle(_ style: TextStyle) -> some View {
        let s = style.spec
        return self
            .font(s.font)
            .tracking(s.tracking)
            .lineSpacing(s.lineSpacing)
            .textCase(s.uppercase ? .uppercase : nil)
    }
}
