//
//  HighlightActionBar.swift
//  Culture
//
//  Created by Mario Martinelli on 23/11/2026.
//

import SwiftUI
import UIKit

/// Bottom panel shown while text is selected or a highlight is tapped:
/// copy, share, note, remove, and the four highlighter inks.
struct HighlightActionBar: View {
    /// The selected / highlighted passage.
    let quote: String
    /// What Share sends (passage + story title).
    let shareText: String
    /// The ink of the highlight being edited; `nil` for a fresh selection.
    var activeColor: HighlightColor?
    var hasNote = false
    var onColor: (HighlightColor) -> Void
    var onNote: () -> Void
    /// Shown only for an existing highlight.
    var onRemove: (() -> Void)?
    var onClose: () -> Void

    @State private var copied = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            Capsule()
                .fill(Palette.hairline)
                .frame(width: 36, height: 4)
                .accessibilityHidden(true)

            HStack(spacing: 0) {
                action(copied ? "Copied" : "Copy", symbol: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = quote
                    copied = true
                }
                ShareLink(item: shareText) { label("Share", symbol: "square.and.arrow.up") }
                    .frame(maxWidth: .infinity)
                action(hasNote ? "Edit Note" : "Note", symbol: hasNote ? "note.text" : "note.text.badge.plus", run: onNote)
                if let onRemove {
                    action("Remove", symbol: "trash", run: onRemove)
                }
            }

            HStack(spacing: Spacing.md) {
                ForEach(HighlightColor.allCases) { color in swatch(color) }
            }

            Button("Close", action: onClose)
                .textStyle(.button)
                .foregroundStyle(Palette.inkSecondary)
                .frame(minWidth: 120, minHeight: HitTarget.minimum)
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.sm)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: Radius.lg, topTrailingRadius: Radius.lg, style: .continuous)
                .fill(Palette.surfaceRaised)
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: Radius.lg, topTrailingRadius: Radius.lg, style: .continuous)
                        .stroke(Palette.hairline, lineWidth: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
        .sensoryFeedback(.success, trigger: copied) { _, new in new }
        .onChange(of: quote) { copied = false }
    }

    private func action(_ title: String, symbol: String, run: @escaping () -> Void) -> some View {
        Button(action: run) { label(title, symbol: symbol) }
            .buttonStyle(.pressable)
            .frame(maxWidth: .infinity)
    }

    private func label(_ title: String, symbol: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .light))
                .frame(height: 24)
                .contentTransition(.symbolEffect(.replace))
            Text(title).textStyle(.label)
        }
        .foregroundStyle(Palette.ink)
        .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
        .contentShape(Rectangle())
    }

    private func swatch(_ color: HighlightColor) -> some View {
        let selected = color == activeColor
        return Button { onColor(color) } label: {
            Circle()
                .fill(color.swatch)
                .frame(width: 30, height: 30)
                .padding(4)
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: selected ? 1.5 : 0))
                .frame(width: HitTarget.minimum, height: HitTarget.minimum)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(color.name) highlight")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: selected)
    }
}

#Preview("New selection") {
    VStack {
        Spacer()
        HighlightActionBar(
            quote: "his ship would return under white sails",
            shareText: "“his ship would return under white sails”\n— Poseidon's Watch",
            onColor: { _ in }, onNote: {}, onClose: {}
        )
    }
    .screenBackground()
    .preferredColorScheme(.dark)
}

#Preview("Existing highlight") {
    VStack {
        Spacer()
        HighlightActionBar(
            quote: "his ship would return under white sails",
            shareText: "“his ship would return under white sails”\n— Poseidon's Watch",
            activeColor: .slate, hasNote: true,
            onColor: { _ in }, onNote: {}, onRemove: {}, onClose: {}
        )
    }
    .screenBackground()
    .preferredColorScheme(.dark)
}
