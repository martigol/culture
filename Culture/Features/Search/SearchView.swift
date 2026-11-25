//
//  SearchView.swift
//  Culture
//
//  Created by Mario Martinelli on 25/11/2026.
//

import SwiftUI

/// The Search tab: global search across every story (title, subtitle, place,
/// era, theme and text), the places you've photographed and your highlights
/// and notes. Theme pills narrow the stories; with no query it suggests a few
/// stories to start from. Each other tab has its own search for just its content.
struct SearchView: View {
    @Environment(\.services) private var services
    @Environment(PhotoStore.self) private var photos
    @Environment(HighlightStore.self) private var highlights

    @State private var query = ""
    @State private var theme: StoryCategory?
    @State private var stories: [Story] = []
    @FocusState private var isFocused: Bool

    private var trimmed: String { InputSanitizer.clean(query, maxLength: 80) }

    private var storyResults: [Story] {
        stories.filter { story in
            (theme == nil || story.category == theme) && (trimmed.isEmpty || story.matches(trimmed))
        }
    }

    private var placeResults: [VisitedPlace] {
        guard !trimmed.isEmpty, theme == nil else { return [] }
        return photos.places.filter {
            $0.name.localizedStandardContains(trimmed) || $0.region.localizedStandardContains(trimmed)
        }
    }

    private var highlightResults: [Highlight] {
        guard !trimmed.isEmpty, theme == nil else { return [] }
        return highlights.highlights.filter {
            $0.text.localizedStandardContains(trimmed) || ($0.note ?? "").localizedStandardContains(trimmed)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                themePills

                if !placeResults.isEmpty {
                    section("Your places") {
                        ForEach(placeResults) { place in
                            NavigationLink(value: Route.album(place.id)) { PlaceResultRow(place: place) }
                                .buttonStyle(.pressable)
                        }
                    }
                }

                if !highlightResults.isEmpty {
                    section("Highlights & notes") {
                        ForEach(highlightResults) { highlight in
                            NavigationLink(value: Route.story(highlight.storyID)) {
                                HighlightRow(highlight: highlight)
                                    .padding(Spacing.sm)
                                    .glassCard(cornerRadius: Radius.cardInner)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                }

                let results = storyResults
                if results.isEmpty && placeResults.isEmpty && highlightResults.isEmpty {
                    EmptyStateView(symbol: "magnifyingglass", title: "Nothing found",
                                   message: "Try a place, a god, a hero or an era — like “Athens”, “Zeus” or “BC”.")
                        .padding(.top, Spacing.xl)
                } else if !results.isEmpty {
                    section(trimmed.isEmpty && theme == nil ? "Start with" : "Stories · \(results.count)") {
                        ForEach(trimmed.isEmpty && theme == nil ? Array(results.prefix(6)) : results) { story in
                            StoryLink(story: story) { StoryResultRow(story: story, query: trimmed) }
                        }
                    }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.section)
            .animation(Motion.smooth, value: trimmed)
            .animation(Motion.smooth, value: theme)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .screenBackground()
        .navigationTitle("Search")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Stories, places, notes…")
        .modifier(FocusSearchOnAppear(isFocused: $isFocused))
        .task { stories = (try? await services.stories.allStories()) ?? MockData.stories }
    }

    private var themePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                pill("All", isSelected: theme == nil) { theme = nil }
                ForEach(StoryCategory.allCases) { category in
                    pill(category.title, isSelected: theme == category) {
                        theme = theme == category ? nil : category
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
        .sensoryFeedback(.selection, trigger: theme)
    }

    private func pill(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
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

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !title.isEmpty {
                Text(title.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(Palette.inkTertiary)
                    .padding(.horizontal, Spacing.xxs)
            }
            rows()
        }
    }

}

extension Story {
    /// Whether the query appears anywhere in the story: title, place, era, theme or text.
    func matches(_ query: String) -> Bool {
        [title, subtitle, region, era, category.title, summary, body]
            .contains { $0.localizedStandardContains(query) }
    }
}

/// A story result on a glass card; says where the match is when it isn't in the title.
private struct StoryResultRow: View {
    let story: Story
    let query: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            ArtworkView(artwork: story.artwork, motion: false)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(story.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text("\(story.region) · \(story.era)")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkTertiary)
                    .lineLimit(1)
                if let snippet {
                    Text(snippet)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(Spacing.sm)
        .glassCard(cornerRadius: Radius.cardInner)
        .accessibilityElement(children: .combine)
    }

    /// "…the oracle spoke in riddles…" when the query matched the text, not the title.
    private var snippet: String? {
        guard !query.isEmpty, !story.title.localizedStandardContains(query) else { return story.subtitle }
        for text in [story.summary, story.body] {
            guard let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else { continue }
            let start = text.index(range.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex
            let end = text.index(range.upperBound, offsetBy: 60, limitedBy: text.endIndex) ?? text.endIndex
            return (start == text.startIndex ? "" : "…") + text[start..<end].trimmingCharacters(in: .whitespaces) + (end == text.endIndex ? "" : "…")
        }
        return story.subtitle
    }
}

private struct PlaceResultRow: View {
    let place: VisitedPlace

    var body: some View {
        HStack(spacing: Spacing.md) {
            SitePhotoImage(photo: place.cover)
                .frame(width: 52, height: 52)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("\(place.photos.count) of your photos")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.inkTertiary)
            }
            Spacer(minLength: 0)
            Image(systemName: "photo.on.rectangle")
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(Spacing.sm)
        .glassCard(cornerRadius: Radius.cardInner)
        .accessibilityElement(children: .combine)
    }
}

/// Puts the cursor in the search field on arrival (iOS 18+).
private struct FocusSearchOnAppear: ViewModifier {
    var isFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .searchFocused(isFocused)
                .task {
                    try? await Task.sleep(for: .milliseconds(350))
                    isFocused.wrappedValue = true
                }
        } else {
            content
        }
    }
}

#Preview {
    NavigationStack { SearchView().appDestinations() }
        .previewEnvironment()
}
