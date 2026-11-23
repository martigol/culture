//
//  NoteEditorSheet.swift
//  Culture
//
//  Created by Mario Martinelli on 23/11/2026.
//

import SwiftUI

/// Write or edit the note attached to a highlight.
struct NoteEditorSheet: View {
    let quote: String
    let color: HighlightColor
    let storyTitle: String
    var onSave: (String) -> Void
    /// Shown only when the highlight already has a note.
    var onDelete: (() -> Void)?

    @State private var note: String
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(quote: String, color: HighlightColor, storyTitle: String, note: String,
         onSave: @escaping (String) -> Void, onDelete: (() -> Void)? = nil) {
        self.quote = quote
        self.color = color
        self.storyTitle = storyTitle
        self.onSave = onSave
        self.onDelete = onDelete
        _note = State(initialValue: note)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack(alignment: .top, spacing: Spacing.sm) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(color.swatch)
                            .frame(width: 3)
                        Text("“\(quote)”")
                            .textStyle(.italic)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .trailing, spacing: Spacing.xs) {
                        TextField("Write a note…", text: $note, axis: .vertical)
                            .textStyle(.body)
                            .foregroundStyle(Palette.ink)
                            .lineLimit(5...)
                            .focused($isFocused)
                            .padding(Spacing.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                                    .strokeBorder(Palette.hairline, lineWidth: 0.75)
                            )
                        Text("\(note.count)/\(HighlightStore.maxNoteLength)")
                            .textStyle(.label)
                            .monospacedDigit()
                            .foregroundStyle(Palette.inkTertiary)
                    }

                    if let onDelete {
                        Button("Delete Note", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        .buttonStyle(.secondary)
                    }
                }
                .padding(Spacing.screen)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle(storyTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(note)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { isFocused = true }
            .onChange(of: note) {
                if note.count > HighlightStore.maxNoteLength { note = String(note.prefix(HighlightStore.maxNoteLength)) }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.lg)
        .presentationBackground(Palette.surface)
    }
}

#Preview("New note") {
    Color.clear.sheet(isPresented: .constant(true)) {
        NoteEditorSheet(quote: "his ship would return under white sails", color: .ochre,
                        storyTitle: "Poseidon's Watch", note: "", onSave: { _ in })
    }
    .preferredColorScheme(.dark)
}

#Preview("Edit note") {
    NoteEditorSheet(quote: "without a single truly straight line", color: .olive,
                    storyTitle: "The Parthenon", note: "Entasis: the columns swell slightly.",
                    onSave: { _ in }, onDelete: {})
        .preferredColorScheme(.dark)
}
