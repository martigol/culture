//
//  Odyssey.swift
//  Culture
//
//  Created by Mario Martinelli on 25/11/2026.
//

import Foundation

/// The game: photograph every site to fill your Odyssey. Each site is a
/// slot that stays locked until you take at least one photo there; ranks
/// mark the way to capturing them all.
struct Odyssey {
    /// Every site, in album order.
    let sites: [Story]
    /// Newest photo per captured site.
    let captured: [Story.ID: SitePhoto]

    init(sites: [Story] = MockData.stories, photos: [SitePhoto]) {
        self.sites = sites
        var latest: [Story.ID: SitePhoto] = [:]
        for photo in photos { // newest first
            if let id = photo.storyID, latest[id] == nil { latest[id] = photo }
        }
        captured = latest.filter { id, _ in sites.contains { $0.id == id } }
    }

    var count: Int { captured.count }
    var total: Int { sites.count }
    var fraction: Double { total == 0 ? 0 : Double(count) / Double(total) }
    var isComplete: Bool { total > 0 && count == total }

    func isCaptured(_ id: Story.ID) -> Bool { captured[id] != nil }

    var rank: OdysseyRank { OdysseyRank.rank(for: count, total: total) }
    var nextRank: OdysseyRank? { OdysseyRank.allCases.first { $0.threshold(total: total) > count } }
    /// Sites still to capture to reach `nextRank`.
    var toNextRank: Int { nextRank.map { $0.threshold(total: total) - count } ?? 0 }
}

/// Titles earned along the way. Olympian means every single site.
enum OdysseyRank: Int, CaseIterable, Comparable {
    case wanderer, traveller, explorer, pilgrim, hero, olympian

    static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }

    /// Sites needed for this rank.
    func threshold(total: Int) -> Int {
        switch self {
        case .wanderer: 0
        case .traveller: 1
        case .explorer: min(5, total)
        case .pilgrim: min(10, total)
        case .hero: min(15, total)
        case .olympian: total
        }
    }

    static func rank(for count: Int, total: Int) -> OdysseyRank {
        allCases.last { count >= $0.threshold(total: total) } ?? .wanderer
    }

    var title: String {
        switch self {
        case .wanderer: "Wanderer"
        case .traveller: "Traveller"
        case .explorer: "Explorer"
        case .pilgrim: "Pilgrim"
        case .hero: "Hero"
        case .olympian: "Olympian"
        }
    }

    /// "an Explorer", "a Pilgrim".
    var withArticle: String { [.explorer, .olympian].contains(self) ? "an \(title)" : "a \(title)" }

    var symbol: String {
        switch self {
        case .wanderer: "figure.walk"
        case .traveller: "map"
        case .explorer: "binoculars"
        case .pilgrim: "building.columns"
        case .hero: "shield.lefthalf.filled"
        case .olympian: "crown"
        }
    }

    var motto: String {
        switch self {
        case .wanderer: "Every journey starts with a single photo."
        case .traveller: "Your first site is captured. The road calls."
        case .explorer: "Five sites. The ancient world is opening up."
        case .pilgrim: "Ten sites. You walk where the faithful walked."
        case .hero: "Fifteen sites. Even Odysseus would be impressed."
        case .olympian: "Every site captured. The gods salute you."
        }
    }
}
