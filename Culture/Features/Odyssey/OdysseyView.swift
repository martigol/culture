//
//  OdysseyView.swift
//  Culture
//
//  Created by Mario Martinelli on 25/11/2026.
//

import SwiftUI

/// "Your Odyssey": every site as a slot in an album. Photograph a site and
/// its slot fills with your picture; locked slots say how far away they are
/// and show the way. Ranks mark the road to capturing them all.
struct OdysseyView: View {
    @Environment(PhotoStore.self) private var photos
    @Environment(LocationProvider.self) private var location
    @Environment(Router.self) private var router
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", captured = "Captured", toFind = "To find"
        var id: String { rawValue }
    }

    private let columns = [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)]

    var body: some View {
        let odyssey = Odyssey(photos: photos.photos)

        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                OdysseyHeader(odyssey: odyssey)
                RankRoad(odyssey: odyssey)
                filterBar
                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    ForEach(sites(odyssey)) { story in
                        Button { open(story, odyssey) } label: {
                            SiteSlot(story: story, photo: odyssey.captured[story.id], distance: distance(to: story))
                        }
                        .buttonStyle(.pressable)
                    }
                }
                .animation(Motion.smooth, value: filter)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.section)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .navigationTitle("Your Odyssey")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.presentScan() } label: { Image(systemName: "camera").fontWeight(.light) }
                    .accessibilityLabel("Take a photo")
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Filter.allCases) { item in
                let isSelected = item == filter
                Button { withAnimation(Motion.snappy) { filter = item } } label: {
                    Text(item.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? Palette.onAccent : Palette.ink)
                        .padding(.horizontal, Spacing.md)
                        .frame(minHeight: 38)
                        .background { if isSelected { Capsule().fill(Palette.accent) } }
                        .glassSurface(in: Capsule(), tint: isSelected ? Palette.accent : nil)
                }
                .buttonStyle(.pressable)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: filter)
    }

    private func sites(_ odyssey: Odyssey) -> [Story] {
        switch filter {
        case .all: odyssey.sites
        case .captured: odyssey.sites.filter { odyssey.isCaptured($0.id) }
        case .toFind:
            // Nearest first, so the next goal is obvious.
            odyssey.sites.filter { !odyssey.isCaptured($0.id) }
                .sorted { (rawDistance(to: $0) ?? .infinity) < (rawDistance(to: $1) ?? .infinity) }
        }
    }

    /// Captured: your album for it. Locked: the way there.
    private func open(_ story: Story, _ odyssey: Odyssey) {
        if odyssey.isCaptured(story.id) {
            router.open(.album(story.id))
        } else {
            router.open(.map(site: story.id))
        }
    }

    private func rawDistance(to story: Story) -> Double? {
        guard let here = location.lastLocation else { return nil }
        return GeoPoint(here.coordinate).distance(to: story.location)
    }

    private func distance(to story: Story) -> String? {
        rawDistance(to: story).map { $0 < 150 ? "You're here" : $0.awayLabel }
    }
}

// MARK: - Header

/// Big progress ring, rank and what's next.
private struct OdysseyHeader: View {
    let odyssey: Odyssey
    @State private var shown = false

    var body: some View {
        HStack(spacing: Spacing.lg) {
            ZStack {
                Circle().stroke(Palette.ink.opacity(0.12), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: shown ? odyssey.fraction : 0)
                    .stroke(Palette.ink, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Palette.imageWarmth.opacity(0.5), radius: 8)
                VStack(spacing: 0) {
                    Text("\(odyssey.count)")
                        .font(.system(size: 34, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                    Text("of \(odyssey.total)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
            .frame(width: 112, height: 112)
            .accessibilityElement()
            .accessibilityLabel("\(odyssey.count) of \(odyssey.total) sites captured")

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label(odyssey.rank.title.uppercased(), systemImage: odyssey.rank.symbol)
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Palette.inkSecondary)
                Text(odyssey.isComplete ? "Odyssey complete" : "Fill your Odyssey")
                    .textStyle(.title)
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .textStyle(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(glow: odyssey.captured.values.first.flatMap { MockData.story($0.storyID ?? "")?.artwork })
        .onAppear { withAnimation(.spring(response: 1.0, dampingFraction: 0.85).delay(0.15)) { shown = true } }
    }

    private var subtitle: String {
        if odyssey.isComplete { return OdysseyRank.olympian.motto }
        guard let next = odyssey.nextRank else { return odyssey.rank.motto }
        let n = odyssey.toNextRank
        return "Photograph \(n) more \(n == 1 ? "site" : "sites") to become \(next.withArticle)."
    }
}

/// The ranks as stepping stones; earned ones lit.
private struct RankRoad: View {
    let odyssey: Odyssey

    var body: some View {
        HStack(spacing: 0) {
            ForEach(OdysseyRank.allCases.dropFirst(), id: \.self) { rank in
                let earned = odyssey.rank >= rank
                VStack(spacing: Spacing.xxs) {
                    Image(systemName: rank.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(earned ? Palette.onAccent : Palette.inkTertiary)
                        .frame(width: 40, height: 40)
                        .background { if earned { Circle().fill(Palette.accent) } }
                        .glassSurface(in: Circle(), tint: earned ? Palette.accent : nil)
                        .shadow(color: earned ? Palette.imageWarmth.opacity(0.5) : .clear, radius: 6)
                    Text(rank.title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(earned ? Palette.ink : Palette.inkTertiary)
                    Text("\(rank.threshold(total: odyssey.total))")
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkTertiary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(rank.title), \(rank.threshold(total: odyssey.total)) sites, \(earned ? "earned" : "not yet")")
            }
        }
    }
}

// MARK: - Slot

/// One site in the album: your photo when captured; a darkened plate,
/// lock and distance while it's still to find.
private struct SiteSlot: View {
    let story: Story
    let photo: SitePhoto?
    let distance: String?

    var body: some View {
        let isCaptured = photo != nil

        ZStack(alignment: .bottomLeading) {
            Group {
                if let photo {
                    SitePhotoImage(photo: photo)
                } else {
                    ArtworkView(artwork: story.artwork, motion: false)
                        .saturation(0)
                        .brightness(-0.35)
                        .blur(radius: 2)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 2) {
                Text(story.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(isCaptured
                     ? "Captured \(photo!.date.formatted(.dateTime.day().month(.abbreviated)))"
                     : (distance ?? story.region))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
            }
            .padding(Spacing.sm)
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: isCaptured ? "checkmark" : "lock.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isCaptured ? Palette.onAccent : Palette.ink)
                .frame(width: 30, height: 30)
                .background { if isCaptured { Circle().fill(Palette.accent) } }
                .glassSurface(in: Circle(), tint: isCaptured ? Palette.accent : nil)
                .padding(Spacing.xs)
        }
        .overlay {
            if !isCaptured {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 28, weight: .ultraLight))
                    .foregroundStyle(Palette.ink.opacity(0.6))
                    .offset(y: -18)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.cardInner, style: .continuous))
        .glassCard(cornerRadius: Radius.cardInner, glow: isCaptured ? story.artwork : nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(story.title), \(isCaptured ? "captured" : "not captured yet\(distance.map { ", \($0)" } ?? "")")")
        .accessibilityHint(isCaptured ? "Opens your photos" : "Shows the way on the map")
    }
}

// MARK: - Home card

/// Compact progress for Home: ring, rank, a strip of slots.
struct OdysseyCard: View {
    @Environment(PhotoStore.self) private var photos

    var body: some View {
        let odyssey = Odyssey(photos: photos.photos)

        NavigationLink(value: Route.odyssey) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Label("YOUR ODYSSEY", systemImage: odyssey.rank.symbol)
                        .font(.caption.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(Palette.inkSecondary)
                    Spacer()
                    Text("\(odyssey.count)/\(odyssey.total) sites")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                }

                GeometryReader { geo in
                    Capsule().fill(Palette.ink.opacity(0.12))
                        .overlay(alignment: .leading) {
                            Capsule().fill(Palette.ink)
                                .frame(width: max(8, geo.size.width * odyssey.fraction))
                                .shadow(color: Palette.imageWarmth.opacity(0.5), radius: 6)
                        }
                }
                .frame(height: 6)

                // The first slots: filled ones show your photo.
                HStack(spacing: 6) {
                    ForEach(odyssey.sites.prefix(7)) { story in
                        Group {
                            if let photo = odyssey.captured[story.id] {
                                SitePhotoImage(photo: photo)
                            } else {
                                ArtworkView(artwork: story.artwork, motion: false)
                                    .saturation(0)
                                    .brightness(-0.4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(odyssey.isCaptured(story.id) ? Palette.ink.opacity(0.8) : Palette.ink.opacity(0.1), lineWidth: 1)
                        )
                    }
                }

                Text(odyssey.isComplete ? "Every site captured. You are an Olympian."
                     : "Photograph every site to fill your Odyssey\(odyssey.nextRank.map { " · \(odyssey.toNextRank) to \($0.title)" } ?? "").")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkTertiary)
                    .multilineTextAlignment(.leading)
            }
            .padding(Spacing.md)
            .glassCard()
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Your Odyssey, \(odyssey.count) of \(odyssey.total) sites captured, rank \(odyssey.rank.title)")
    }
}

// MARK: - Celebration

/// Full-screen moment when a photo captures a site for the first time:
/// your photo in a glowing medallion, the ring filling to the new total,
/// a burst of light, and the rank if you just earned one.
struct SiteCapturedCelebration: View {
    let story: Story
    var onContinue: () -> Void
    var onOpenOdyssey: () -> Void

    @Environment(PhotoStore.self) private var photos
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var ringFill: Double = 0
    @State private var burst = false

    var body: some View {
        let odyssey = Odyssey(photos: photos.photos)
        let before = OdysseyRank.rank(for: odyssey.count - 1, total: odyssey.total)
        let rankedUp = odyssey.rank > before
        let photo = odyssey.captured[story.id]

        ZStack {
            Color.black.opacity(0.82).ignoresSafeArea()
                .onTapGesture(perform: onContinue)

            VStack(spacing: Spacing.lg) {
                Text(rankedUp ? "NEW RANK" : "SITE CAPTURED")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(Palette.inkSecondary)

                ZStack {
                    // Light burst.
                    ForEach(0..<18, id: \.self) { i in
                        Capsule()
                            .fill(Palette.imageWarmth)
                            .frame(width: 3, height: 14)
                            .offset(y: burst ? -150 : -70)
                            .rotationEffect(.degrees(Double(i) * 20))
                            .opacity(burst ? 0 : 0.9)
                    }

                    Circle().stroke(Palette.ink.opacity(0.15), lineWidth: 6).frame(width: 196, height: 196)
                    Circle()
                        .trim(from: 0, to: ringFill)
                        .stroke(Palette.ink, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 196, height: 196)
                        .shadow(color: Palette.imageWarmth.opacity(0.7), radius: 10)

                    Group {
                        if let photo {
                            SitePhotoImage(photo: photo)
                        } else {
                            ArtworkView(artwork: story.artwork, motion: false)
                        }
                    }
                    .frame(width: 168, height: 168)
                    .clipShape(Circle())
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: rankedUp ? odyssey.rank.symbol : "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Palette.onAccent)
                            .frame(width: 46, height: 46)
                            .background(Palette.accent, in: Circle())
                            .shadow(color: .black.opacity(0.4), radius: 6)
                            .scaleEffect(appeared ? 1 : 0.2)
                    }
                }
                .scaleEffect(appeared ? 1 : 0.7)

                VStack(spacing: Spacing.xs) {
                    Text(rankedUp ? "You are now \(odyssey.rank.withArticle)" : story.title)
                        .textStyle(.display)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                    Text(rankedUp ? odyssey.rank.motto : "joins your Odyssey · \(odyssey.count) of \(odyssey.total) sites")
                        .textStyle(.body)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.center)
                    if rankedUp {
                        Text("\(story.title) · \(odyssey.count) of \(odyssey.total) sites")
                            .textStyle(.label)
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                VStack(spacing: Spacing.sm) {
                    Button("Continue", action: onContinue)
                        .buttonStyle(.primary)
                    Button("See your Odyssey", action: onOpenOdyssey)
                        .buttonStyle(.secondary)
                }
                .opacity(appeared ? 1 : 0)
            }
            .padding(.horizontal, Spacing.screen)
        }
        .sensoryFeedback(.success, trigger: appeared)
        .onAppear {
            let previous = Double(max(odyssey.count - 1, 0)) / Double(max(odyssey.total, 1))
            ringFill = previous
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appeared = true }
            withAnimation(.easeOut(duration: reduceMotion ? 0.2 : 1.1).delay(0.3)) { ringFill = odyssey.fraction }
            if !reduceMotion {
                withAnimation(.easeOut(duration: 0.9).delay(0.25)) { burst = true }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

#Preview("Odyssey") {
    NavigationStack { OdysseyView().appDestinations() }
        .previewEnvironment()
}

#Preview("Home card") {
    NavigationStack {
        OdysseyCard().padding(Spacing.md).frame(maxHeight: .infinity).screenBackground()
    }
    .previewEnvironment()
}

#Preview("Celebration") {
    SiteCapturedCelebration(story: MockData.story("parthenon")!, onContinue: {}, onOpenOdyssey: {})
        .background(ArtworkView(artwork: MockData.stories[0].artwork).ignoresSafeArea())
        .previewEnvironment()
}
