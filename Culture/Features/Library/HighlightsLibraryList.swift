//
//  HighlightsLibraryList.swift
//  Culture
//
//  Created by Mario Martinelli on 23/11/2026.
//

import SwiftUI

/// Library ▸ Highlights & Notes: every highlight, grouped by story.
/// Tap a passage to open its story; long-press to delete it.
struct HighlightsLibraryList: View {
    @Environment(HighlightStore.self) private var store

    var body: some View {
        ForEach(store.groups) { group in
            if let story = MockData.story(group.storyID) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    StoryLink(story: story) { header(story, count: group.items.count) }

                    ForEach(group.items) { highlight in
                        NavigationLink(value: Route.story(story.id)) {
                            HighlightRow(highlight: highlight)
                        }
                        .buttonStyle(.pressable)
                        .contextMenu {
                            ShareLink(item: "“\(highlight.text)”\n— \(story.title)") {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            Button(role: .destructive) {
                                withAnimation(Motion.smooth) { store.remove(highlight.id) }
                            } label: {
                                Label("Delete Highlight", systemImage: "trash")
                            }
                        }
                    }
                }
                .modifier(RowChrome())
            }
        }
    }

    private func header(_ story: Story, count: Int) -> some View {
        HStack(spacing: Spacing.md) {
            ArtworkView(artwork: story.artwork)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: Radius.xs))
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(story.title).textStyle(.headline).foregroundStyle(Palette.ink)
                Text(count == 1 ? "1 highlight" : "\(count) highlights")
                    .textStyle(.label)
                    .foregroundStyle(Palette.inkTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(Palette.inkTertiary)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            LazyVStack(spacing: 0) { HighlightsLibraryList() }
        }
        .screenBackground()
        .navigationTitle("Highlights & Notes")
        .appDestinations()
    }
    .previewEnvironment()
}
