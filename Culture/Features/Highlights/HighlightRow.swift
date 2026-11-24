//
//  HighlightRow.swift
//  Culture
//
//  Created by Mario Martinelli on 23/11/2026.
//

import SwiftUI

/// A highlighted passage with its ink marker, note and date.
/// Used in Story detail ("Your highlights") and Library ▸ Highlights & Notes.
struct HighlightRow: View {
    let highlight: Highlight

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 1)
                .fill(highlight.color.swatch)
                .frame(width: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("“\(highlight.text)”")
                    .textStyle(.italic)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(4)
                if let note = highlight.note, !note.isEmpty {
                    Label {
                        Text(note)
                            .textStyle(.footnote)
                            .foregroundStyle(Palette.inkSecondary)
                            .lineLimit(3)
                    } icon: {
                        Image(systemName: "note.text")
                            .font(.footnote.weight(.light))
                            .foregroundStyle(Palette.inkTertiary)
                    }
                }
                Text(highlight.updatedAt, format: .relative(presentation: .named))
                    .textStyle(.label)
                    .foregroundStyle(Palette.inkTertiary)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(highlight.color.name) highlight: \(highlight.text)" + (highlight.note.map { ". Note: \($0)" } ?? ""))
    }
}

/// "Your highlights" list under a story's article.
struct StoryHighlightsSection: View {
    let highlights: [Highlight]
    var onSelect: (Highlight) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Your highlights", actionTitle: nil)
            VStack(spacing: 0) {
                ForEach(Array(highlights.enumerated()), id: \.element.id) { index, highlight in
                    Button { onSelect(highlight) } label: { HighlightRow(highlight: highlight) }
                        .buttonStyle(.pressable)
                        .padding(.vertical, Spacing.sm)
                        .overlay(alignment: .bottom) {
                            if index < highlights.count - 1 {
                                Rectangle().fill(Palette.hairline).frame(height: 0.5)
                            }
                        }
                }
            }
            .padding(.horizontal, Spacing.screen)
        }
    }
}

#Preview("Row") {
    VStack(spacing: Spacing.lg) {
        ForEach(HighlightStore.preview.highlights) { HighlightRow(highlight: $0) }
    }
    .padding(Spacing.screen)
    .screenBackground()
    .preferredColorScheme(.dark)
}

#Preview("Story section") {
    ScrollView {
        StoryHighlightsSection(highlights: HighlightStore.preview.highlights(for: "sounion")) { _ in }
    }
    .screenBackground()
    .preferredColorScheme(.dark)
}
