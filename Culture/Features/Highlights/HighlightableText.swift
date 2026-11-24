//
//  HighlightableText.swift
//  Culture
//
//  Created by Mario Martinelli on 23/11/2026.
//

import SwiftUI
import UIKit

/// Reading text the user can select, highlight and annotate.
///
/// Backed by a non-editable `UITextView` because SwiftUI `Text` can't report a
/// selection range or add items to the edit menu. Styled like
/// `.textStyle(.body)` in `Palette.inkSecondary`; highlighted passages get an
/// ink wash, and passages with a note get a dotted underline.
struct HighlightableText: UIViewRepresentable {
    enum MenuAction { case highlight, note }

    let text: String
    var highlights: [Highlight] = []
    /// Current selection (UTF-16 range in `text`), `nil` when nothing is selected.
    /// Set it to `nil` to clear the selection.
    @Binding var selection: NSRange?
    /// Collapsed line count; `nil` shows everything.
    var lineLimit: Int?
    var onTapHighlight: (Highlight) -> Void = { _ in }
    /// "Highlight" / "Add Note" chosen from the system edit menu.
    var onMenuAction: (MenuAction, NSRange) -> Void = { _, _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        // TextKit 1: dependable line limits and character hit-testing.
        let view = UITextView(usingTextLayoutManager: false)
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.textContainer.lineBreakMode = .byTruncatingTail
        view.dataDetectorTypes = []
        view.tintColor = UIColor(Palette.ink)
        view.delegate = context.coordinator
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        context.coordinator.render(into: view)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.render(into: view)
        if selection == nil, view.selectedRange.length > 0 {
            view.selectedRange = NSRange(location: 0, length: 0)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let proposed = proposal.width.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let width = proposed ?? (uiView.bounds.width > 0 ? uiView.bounds.width : 320)
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: HighlightableText
        private var renderedKey: Int?

        init(_ parent: HighlightableText) { self.parent = parent }

        /// Rebuilds the attributed text only when its inputs change, so an
        /// in-progress selection isn't wiped by unrelated SwiftUI updates.
        func render(into view: UITextView) {
            var hasher = Hasher()
            hasher.combine(parent.text)
            hasher.combine(parent.highlights)
            hasher.combine(parent.lineLimit)
            hasher.combine(view.traitCollection.preferredContentSizeCategory)
            let key = hasher.finalize()
            guard key != renderedKey else { return }
            renderedKey = key

            view.textContainer.maximumNumberOfLines = parent.lineLimit ?? 0
            view.attributedText = Self.attributed(parent.text, highlights: parent.highlights)
            view.invalidateIntrinsicContentSize()
        }

        static func attributed(_ text: String, highlights: [Highlight]) -> NSAttributedString {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 6 // matches TextStyle.body
            let result = NSMutableAttributedString(string: text, attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor(Palette.inkSecondary),
                .paragraphStyle: paragraph,
            ])
            for highlight in highlights where highlight.length > 0 && NSMaxRange(highlight.range) <= result.length {
                result.addAttributes([
                    .backgroundColor: highlight.color.wash,
                    .foregroundColor: UIColor(Palette.ink),
                ], range: highlight.range)
                if highlight.hasNote {
                    result.addAttributes([
                        .underlineStyle: NSUnderlineStyle.single.rawValue | NSUnderlineStyle.patternDot.rawValue,
                        .underlineColor: UIColor(highlight.color.swatch),
                    ], range: highlight.range)
                }
            }
            return result
        }

        // MARK: UITextViewDelegate

        func textViewDidChangeSelection(_ textView: UITextView) {
            let range = textView.selectedRange
            let newValue: NSRange? = range.length > 0 ? range : nil
            guard newValue != parent.selection else { return }
            // Defer: this can fire during a SwiftUI update pass.
            DispatchQueue.main.async { [weak self] in self?.parent.selection = newValue }
        }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange,
                      suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard range.length > 0 else { return nil }
            let highlight = UIAction(title: "Highlight", image: UIImage(systemName: "highlighter")) { [weak self] _ in
                self?.parent.onMenuAction(.highlight, range)
            }
            let note = UIAction(title: "Add Note", image: UIImage(systemName: "note.text.badge.plus")) { [weak self] _ in
                self?.parent.onMenuAction(.note, range)
            }
            return UIMenu(children: [highlight, note] + suggestedActions)
        }

        // MARK: Tap on an existing highlight

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? UITextView, view.selectedRange.length == 0 else { return }
            var point = gesture.location(in: view)
            point.x -= view.textContainerInset.left
            point.y -= view.textContainerInset.top

            let layout = view.layoutManager
            let glyph = layout.glyphIndex(for: point, in: view.textContainer, fractionOfDistanceThroughGlyph: nil)
            let glyphRect = layout.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: view.textContainer)
            guard glyphRect.contains(point) else { return }

            let index = layout.characterIndexForGlyph(at: glyph)
            if let hit = parent.highlights.first(where: { NSLocationInRange(index, $0.range) }) {
                parent.onTapHighlight(hit)
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

#Preview {
    @Previewable @State var selection: NSRange? = nil
    let story = MockData.story("sounion")!

    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HighlightableText(
                text: story.body,
                highlights: HighlightStore.preview.highlights(for: story.id),
                selection: $selection
            )
            Text(selection.map { "Selected \($0.length) characters" } ?? "Long-press to select text")
                .textStyle(.footnote)
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(Spacing.screen)
    }
    .screenBackground()
    .preferredColorScheme(.dark)
}
