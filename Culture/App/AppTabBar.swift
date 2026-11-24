//
//  AppTabBar.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import SwiftUI

/// The app's bottom navigation, in Liquid Glass.
///
/// At rest it's one bar with every tab, Scan in the middle in plain glass.
/// Scrolling down splits it into three floating buttons — Home, Scan (now the
/// biggest, tinted bone) and Library — and scrolling back up, reaching the
/// top or switching tabs brings the full bar back. Before iOS 26 it falls
/// back to a frosted material.
struct AppTabBar: View {
    @Environment(Router.self) private var router
    @Namespace private var glass

    private let barHeight: CGFloat = 64
    private let circleSize: CGFloat = 54
    private let scanSize: CGFloat = 66

    var body: some View {
        container {
            if router.isTabBarCollapsed { collapsed } else { expanded }
        }
        .frame(height: scanSize)
        .padding(.horizontal, Spacing.screen)
        .padding(.bottom, Spacing.xxs)
        .sensoryFeedback(.selection, trigger: router.selectedTab)
    }

    // MARK: Layouts

    /// One glass bar: every tab, Scan in the middle as part of the bar.
    private var expanded: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                if tab == .scan {
                    scanBarItem
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeight)
                        .modifier(GlassStyle(shape: Capsule(), id: tab, union: "bar", namespace: glass))
                } else {
                    barItem(tab)
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeight)
                        .modifier(GlassStyle(shape: Capsule(), id: tab, union: "bar", namespace: glass))
                }
            }
        }
        .modifier(LegacyBarBackground())
    }

    /// Three floating circles: Home · Scan · Library.
    private var collapsed: some View {
        HStack(spacing: 0) {
            circleItem(.home)
            Spacer(minLength: 0)
            scanButton
            Spacer(minLength: 0)
            circleItem(.library)
        }
    }

    // MARK: Items

    private func barItem(_ tab: AppTab) -> some View {
        let isSelected = router.selectedTab == tab
        return Button { select(tab) } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol)
                    .symbolVariant(isSelected ? .fill : .none)
                    .font(.system(size: 19, weight: .regular))
                    .frame(height: 22)
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? Palette.ink : Palette.inkTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func circleItem(_ tab: AppTab) -> some View {
        let isSelected = router.selectedTab == tab
        return Button { select(tab) } label: {
            Image(systemName: tab.symbol)
                .symbolVariant(isSelected ? .fill : .none)
                .font(.system(size: 21, weight: .regular))
                .foregroundStyle(isSelected ? Palette.ink : Palette.inkSecondary)
                .frame(width: circleSize, height: circleSize)
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .modifier(GlassStyle(shape: Circle(), id: tab, union: nil, namespace: glass))
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Scan inside the full bar: plain glass like its neighbours, a slightly larger glyph.
    private var scanBarItem: some View {
        Button { router.presentScan() } label: {
            CaptureModeIcon(mode: .scan, size: 26)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Scan")
        .accessibilityHint("Opens the camera")
    }

    /// Scan once the bar has collapsed: the largest button, tinted bone.
    private var scanButton: some View {
        Button { router.presentScan() } label: {
            CaptureModeIcon(mode: .scan, size: 28)
                .foregroundStyle(Palette.onAccent)
                .frame(width: scanSize, height: scanSize)
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .modifier(GlassStyle(shape: Circle(), id: AppTab.scan, union: nil, namespace: glass, tint: Palette.accent))
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .accessibilityLabel("Scan")
        .accessibilityHint("Opens the camera")
    }

    private func select(_ tab: AppTab) {
        if tab == router.selectedTab {
            // Tapping the current tab pops back to its root.
            router.paths[tab] = []
        }
        router.selectedTab = tab
        router.setTabBarCollapsed(false)
    }

    /// Lets the glass shapes morph into each other (iOS 26+).
    @ViewBuilder
    private func container(@ViewBuilder _ content: () -> some View) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 18) { content() }
        } else {
            content()
        }
    }
}

/// Liquid Glass on iOS 26 (morphing via shared IDs, optionally merged into one
/// bar), frosted material before that.
private struct GlassStyle<S: Shape>: ViewModifier {
    let shape: S
    let id: AppTab
    let union: String?
    let namespace: Namespace.ID
    var tint: Color? = nil

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(glass, in: shape)
                .glassEffectID(id, in: namespace)
                .glassEffectUnion(id: union, namespace: namespace)
                .glassEffectTransition(.matchedGeometry)
        } else if union != nil {
            content // part of the one bar; see LegacyBarBackground
        } else {
            content
                .background {
                    if let tint {
                        shape.fill(tint)
                    } else {
                        shape.fill(.ultraThinMaterial)
                    }
                }
                .overlay(shape.stroke(Palette.ink.opacity(0.12), lineWidth: 0.75))
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        if let tint { .regular.tint(tint).interactive() } else { .regular.interactive() }
    }
}

/// Before iOS 26: one frosted capsule behind the whole expanded bar
/// (on iOS 26 the items' glass merges into one shape instead).
private struct LegacyBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Palette.ink.opacity(0.12), lineWidth: 0.75))
        }
    }
}

extension View {
    /// Collapses the tab bar while this view's scroll view scrolls down, and
    /// restores it on scrolling up or near the top (iOS 18+).
    func collapsesTabBarOnScroll() -> some View {
        modifier(CollapsesTabBarOnScroll())
    }
}

private struct CollapsesTabBarOnScroll: ViewModifier {
    @Environment(Router.self) private var router

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { old, new in
                let delta = new - old
                if new < 30 {
                    router.setTabBarCollapsed(false)
                } else if delta > 4 {
                    router.setTabBarCollapsed(true)
                } else if delta < -4 {
                    router.setTabBarCollapsed(false)
                }
            }
        } else {
            content
        }
    }
}

private struct TabBarPreview: View {
    var collapsed: Bool
    @Environment(Router.self) private var router

    var body: some View {
        VStack {
            Spacer()
            AppTabBar()
        }
        .background(ArtworkView(artwork: MockData.stories[0].artwork, motion: false).ignoresSafeArea())
        .onAppear { router.setTabBarCollapsed(collapsed) }
    }
}

#Preview("Expanded") {
    TabBarPreview(collapsed: false).previewEnvironment()
}

#Preview("Collapsed on scroll") {
    TabBarPreview(collapsed: true).previewEnvironment()
}
