//
//  RecommendationService.swift
//  Culture
//
//  Created by Mario Martinelli on 23/11/2026.
//

import Foundation

/// What the app knows about the reader's interests. Built only from local
/// state (LibraryStore + HighlightStore), so nothing leaves the device.
struct UserSignals: Hashable, Sendable {
    /// Most recent first. Repeats count (scanning twice = stronger interest).
    var scannedIDs: [Story.ID] = []
    /// Most recent first.
    var savedIDs: [Story.ID] = []
    var highlightCounts: [Story.ID: Int] = [:]
    /// Most recent first.
    var readIDs: [Story.ID] = []

    var isEmpty: Bool {
        scannedIDs.isEmpty && savedIDs.isEmpty && highlightCounts.isEmpty && readIDs.isEmpty
    }
}

struct Recommendation: Identifiable, Hashable, Sendable {
    enum Reason: Hashable, Sendable {
        case scanned(String)
        case highlighted(String)
        case saved(String)
        case read(String)
        case editorsPick
        case explore(String)

        var text: String {
            switch self {
            case .scanned(let title): "Because you scanned \(title)"
            case .highlighted(let title): "Because you highlighted \(title)"
            case .saved(let title): "Because you saved \(title)"
            case .read(let title): "Because you read \(title)"
            case .editorsPick: "Editor's pick"
            case .explore(let theme): "Explore \(theme)"
            }
        }

        var symbol: String {
            switch self {
            case .scanned: "viewfinder"
            case .highlighted: "highlighter"
            case .saved: "bookmark"
            case .read: "book"
            case .editorsPick: "sparkles"
            case .explore: "safari"
            }
        }
    }

    let story: Story
    let score: Double
    let reason: Reason
    var id: Story.ID { story.id }
}

/// Personalised ranking. Swap for a server-side recommender in `AppEnvironment`.
protocol Recommending: Sendable {
    func recommend(from catalog: [Story], signals: UserSignals, limit: Int) -> [Recommendation]
    func similar(to story: Story, in catalog: [Story], limit: Int) -> [Story]
}

/// On-device, content-based recommender.
///
/// 1. Every interaction becomes a weighted *seed* (scan > highlight > save > read),
///    decaying with age so recent interests count more.
/// 2. Each candidate scores `Σ seed.weight × similarity(seed, candidate)`.
///    Similarity = same theme + same region + close in time + shared names
///    (Theseus, Agamemnon, Apollo…) found in the text.
/// 3. Stories already seen are pushed down (not hidden). Editor's picks get a
///    small boost so a new user still sees a curated page.
/// 4. Re-ranking keeps themes varied, so the list isn't five myths in a row.
struct ContentBasedRecommender: Recommending {
    struct Weights: Sendable {
        var scan = 3.0
        var highlight = 2.5
        var save = 2.0
        var read = 1.0
        /// Each older interaction counts this much of the newer one.
        var recencyDecay = 0.8
        var editorial = 0.4
        var seenPenalty = 0.3
        /// Score multiplier per already-picked story with the same theme.
        var diversity = 0.75
    }

    var weights = Weights()

    func recommend(from catalog: [Story], signals: UserSignals, limit: Int = 10) -> [Recommendation] {
        let byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let seeds = seeds(from: signals, byID: byID)
        let seen = Set(signals.scannedIDs + signals.savedIDs + signals.readIDs + Array(signals.highlightCounts.keys))

        let scored: [Recommendation] = catalog.map { candidate in
            var score = candidate.isRecommended ? weights.editorial : 0
            var best: (contribution: Double, reason: Recommendation.Reason)?
            for seed in seeds where seed.story.id != candidate.id {
                let contribution = seed.weight * Self.similarity(seed.story, candidate)
                score += contribution
                if contribution > (best?.contribution ?? 0) { best = (contribution, seed.reason) }
            }
            if seen.contains(candidate.id) { score *= weights.seenPenalty }
            let fallback: Recommendation.Reason = candidate.isRecommended
                ? .editorsPick : .explore(candidate.category.title)
            return Recommendation(story: candidate, score: score, reason: best?.reason ?? fallback)
        }

        return diversified(scored.sorted { $0.score > $1.score }, limit: limit)
    }

    func similar(to story: Story, in catalog: [Story], limit: Int = 6) -> [Story] {
        catalog
            .filter { $0.id != story.id }
            .map { (story: $0, score: Self.similarity(story, $0)) }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.story }
    }

    // MARK: Similarity

    /// 0…1.4: theme 0.5 · region 0.3 · era 0.2 · shared names 0.4.
    static func similarity(_ a: Story, _ b: Story) -> Double {
        var score = 0.0
        if a.category == b.category { score += 0.5 }
        if a.region == b.region { score += 0.3 }
        if let ya = approximateYear(a.era), let yb = approximateYear(b.era) {
            score += 0.2 * max(0, 1 - Double(abs(ya - yb)) / 1_000)
        }
        let shared = properNouns(in: a).intersection(properNouns(in: b)).count
        score += 0.4 * min(1, Double(shared) / 3)
        return score
    }

    /// Rough year from an era label ("447–432 BC", "c. 1550 BC",
    /// "8th c. BC – AD 390"). BC years are negative.
    static func approximateYear(_ era: String) -> Int? {
        guard let start = era.firstIndex(where: \.isNumber) else { return nil }
        let digits = era[start...].prefix(while: \.isNumber)
        guard var year = Int(digits) else { return nil }
        let after = era[digits.endIndex...]
        let suffix = after.trimmingCharacters(in: .whitespaces).lowercased()
        if ["st", "nd", "rd", "th"].contains(where: { suffix.hasPrefix($0) }), suffix.contains("c.") {
            year = (year - 1) * 100 + 50 // century → its midpoint
        }
        if era[..<start].hasSuffix("AD ") { return year }
        switch (after.range(of: "BC"), after.range(of: "AD")) {
        case let (bc?, ad?): return bc.lowerBound < ad.lowerBound ? -year : year
        case (.some, nil): return -year
        default: return year
        }
    }

    /// Capitalised words that don't start a sentence: names of people, gods, places.
    static func properNouns(in story: Story) -> Set<String> {
        let text = [story.title, story.subtitle, story.summary, story.body].joined(separator: ". ")
        var result = Set<String>()
        var previousEnd = text.startIndex
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { word, range, _, _ in
            defer { previousEnd = range.upperBound }
            guard let word, word.count >= 4, word.first?.isUppercase == true else { return }
            let gap = text[previousEnd..<range.lowerBound]
            let startsSentence = range.lowerBound == text.startIndex || gap.contains { ".!?\n—:".contains($0) }
            if !startsSentence { result.insert(word.lowercased()) }
        }
        return result
    }

    // MARK: Private

    private struct Seed {
        let story: Story
        let weight: Double
        let reason: Recommendation.Reason
    }

    private func seeds(from signals: UserSignals, byID: [Story.ID: Story]) -> [Seed] {
        var seeds: [Seed] = []
        func add(_ ids: [Story.ID], base: Double, reason: (String) -> Recommendation.Reason) {
            for (age, id) in ids.enumerated() {
                guard let story = byID[id] else { continue }
                let weight = base * pow(weights.recencyDecay, Double(age))
                seeds.append(Seed(story: story, weight: weight, reason: reason(story.title)))
            }
        }
        add(signals.scannedIDs, base: weights.scan, reason: Recommendation.Reason.scanned)
        add(signals.savedIDs, base: weights.save, reason: Recommendation.Reason.saved)
        add(signals.readIDs, base: weights.read, reason: Recommendation.Reason.read)
        for (id, count) in signals.highlightCounts {
            guard let story = byID[id], count > 0 else { continue }
            let weight = weights.highlight * (1 + log(Double(count)))
            seeds.append(Seed(story: story, weight: weight, reason: .highlighted(story.title)))
        }
        return seeds
    }

    private func diversified(_ ranked: [Recommendation], limit: Int) -> [Recommendation] {
        var pool = ranked
        var picked: [Recommendation] = []
        while !pool.isEmpty, picked.count < limit {
            var bestIndex = 0
            var bestScore = -Double.infinity
            for (i, candidate) in pool.enumerated() {
                let sameTheme = picked.filter { $0.story.category == candidate.story.category }.count
                let adjusted = candidate.score * pow(weights.diversity, Double(sameTheme))
                if adjusted > bestScore { bestScore = adjusted; bestIndex = i }
            }
            picked.append(pool.remove(at: bestIndex))
        }
        return picked
    }
}
