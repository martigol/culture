import UIKit

/// UIKit appearance for system chrome SwiftUI can't style directly.
enum Appearance {
    static func configure() {
        let ink = UIColor(Palette.ink)
        let nav = UINavigationBar.appearance()
        if let large = UIFont(name: "Zodiak-Regular", size: 34) {
            nav.largeTitleTextAttributes = [
                .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large),
                .foregroundColor: ink,
                .kern: -0.5,
            ]
        }
        if let inline = UIFont(name: "Zodiak-Regular", size: 15) {
            nav.titleTextAttributes = [
                .font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: inline),
                .foregroundColor: ink,
                .kern: 2.4,
            ]
        }
    }
}
