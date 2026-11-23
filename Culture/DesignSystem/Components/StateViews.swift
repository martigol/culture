import SwiftUI

/// Loading / content / failure wrapper so every screen handles all states.
enum Loadable<Value> {
    case loading
    case loaded(Value)
    case failed(String)
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(Palette.inkSecondary)
            Text(title).textStyle(.title).foregroundStyle(Palette.ink)
            Text(message).textStyle(.footnote).foregroundStyle(Palette.inkSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

/// Skeleton placeholder with a soft shimmer (no spinners).
struct LoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: Radius.sm).fill(Palette.surface).frame(height: 220)
            RoundedRectangle(cornerRadius: Radius.xs).fill(Palette.surface).frame(width: 120, height: 10)
            RoundedRectangle(cornerRadius: Radius.xs).fill(Palette.surface).frame(width: 240, height: 22)
            RoundedRectangle(cornerRadius: Radius.xs).fill(Palette.surface).frame(width: 180, height: 14)
        }
        .shimmer()
        .padding(Spacing.screen)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Loading")
    }
}

extension View {
    /// Standard screen background applied consistently.
    func screenBackground() -> some View {
        background(Palette.background.ignoresSafeArea())
    }
}
