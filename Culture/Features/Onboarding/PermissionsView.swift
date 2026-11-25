//
//  PermissionsView.swift
//  Culture
//
//  Created by Mario Martinelli on 25/11/2026.
//

import SwiftUI

/// "Get the full experience": every feature the app needs, why, and one tap
/// to turn it on. Shown on first launch; reopen any time from Library.
struct PermissionsView: View {
    var onDone: () -> Void

    @Environment(PermissionsCenter.self) private var permissions
    @Environment(NearbySiteAlerts.self) private var alerts
    @Environment(LocationProvider.self) private var location
    @Environment(\.services) private var services
    @Environment(\.scenePhase) private var scenePhase
    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                header

                VStack(spacing: Spacing.sm) {
                    ForEach(PermissionsCenter.Feature.allCases) { feature in
                        FeatureRow(feature: feature, status: permissions.status(of: feature)) {
                            Task { await request(feature) }
                        }
                    }
                }

                nearbyToggle

                Text("Everything stays on your iPhone. You can change these any time in Settings.")
                    .textStyle(.footnote)
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(.horizontal, Spacing.xxs)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xl)
            .padding(.bottom, 140)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) { footer }
        .screenBackground()
        .task { await permissions.refresh() }
        .onChange(of: scenePhase) { _, phase in
            // Back from Settings: pick up the change.
            if phase == .active { Task { await refreshAll() } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: "building.columns")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Palette.ink)
                .frame(width: 64, height: 64)
                .glassSurface(in: Circle())
            Text("Get the full experience")
                .textStyle(.display)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("CLIO works best with a few things switched on. Here's what each one does.")
                .textStyle(.body)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nearbyToggle: some View {
        Toggle(isOn: Binding(
            get: { alerts.isEnabled },
            set: { on in Task { await alerts.setEnabled(on, sites: await sites()) } }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Alert me near historical sites")
                    .textStyle(.callout)
                    .foregroundStyle(Palette.ink)
                Text("Within \(NearbySiteAlerts.radius.distanceLabel), with how far it is and why it's worth it.")
                    .textStyle(.label)
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
        .tint(Palette.accent)
        .padding(Spacing.md)
        .glassCard(cornerRadius: Radius.cardInner)
        .safeAreaInset(edge: .bottom, spacing: Spacing.sm) {
            if permissions.status(of: .notifications) == .granted {
                Button {
                    Task {
                        let story = await sites().randomElement() ?? MockData.stories[0]
                        await alerts.sendTest(for: story)
                    }
                } label: {
                    Label("Preview an alert", systemImage: "bell.and.waves.left.and.right")
                }
                .buttonStyle(.secondary)
                .accessibilityHint("Shows a nearby-site notification in a few seconds")
            }
        }
    }

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            if permissions.allGranted {
                Button("Start exploring", action: finish)
                    .buttonStyle(.primary)
            } else {
                Button {
                    Task {
                        isRequesting = true
                        await permissions.requestAll(location: location)
                        await refreshAll()
                        isRequesting = false
                    }
                } label: {
                    if isRequesting { ProgressView().tint(Palette.onAccent) } else { Text("Allow all") }
                }
                .buttonStyle(.primary)
                .disabled(isRequesting)
                Button("Not now", action: finish)
                    .buttonStyle(.secondary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .background(LinearGradient(colors: [Palette.background.opacity(0), Palette.background], startPoint: .top, endPoint: .center))
    }

    private func request(_ feature: PermissionsCenter.Feature) async {
        await permissions.request(feature, location: location)
        await refreshAll()
    }

    /// Statuses, plus the site alerts (they need location + notifications).
    private func refreshAll() async {
        await permissions.refresh()
        await alerts.refresh(sites: await sites())
    }

    private func sites() async -> [Story] {
        (try? await services.stories.allStories()) ?? MockData.stories
    }

    private func finish() {
        permissions.hasCompletedOnboarding = true
        onDone()
    }
}

/// One feature: icon, what it's for, and its state / action on a glass card.
private struct FeatureRow: View {
    let feature: PermissionsCenter.Feature
    let status: PermissionsCenter.Status
    var onRequest: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Image(systemName: feature.symbol)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Palette.ink)
                .frame(width: 44, height: 44)
                .glassSurface(in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .textStyle(.callout)
                    .foregroundStyle(Palette.ink)
                Text(feature.reason)
                    .textStyle(.label)
                    .foregroundStyle(Palette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(Spacing.md)
        .glassCard(cornerRadius: Radius.cardInner)
        .accessibilityElement(children: .combine)
        .animation(Motion.snappy, value: status)
    }

    @ViewBuilder
    private var trailing: some View {
        switch status {
        case .granted:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(Palette.ink)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("On")
        case .notAsked:
            pill("Allow", action: onRequest)
        case .denied:
            pill("Settings", action: onRequest)
        case .needsSettings(let hint):
            pill("Settings", action: onRequest).accessibilityHint(hint)
        case .unavailable(let reason):
            Text(reason)
                .textStyle(.label)
                .foregroundStyle(Palette.inkTertiary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 96, alignment: .trailing)
        }
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.onAccent)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 36)
                .background(Palette.accent, in: Capsule())
                .glassSurface(in: Capsule(), tint: Palette.accent)
        }
        .buttonStyle(.pressable)
    }
}

#Preview {
    PermissionsView {}
        .environment(PermissionsCenter())
        .environment(NearbySiteAlerts())
        .previewEnvironment()
}
