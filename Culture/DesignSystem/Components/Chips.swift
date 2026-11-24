import SwiftUI

/// Editorial filter bar: text tabs with a hairline underline.
struct ChipBar<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    @Namespace private var underline

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.lg) {
                ForEach(items, id: \.self) { item in
                    let selected = item == selection
                    Button {
                        withAnimation(Motion.spring) { selection = item }
                    } label: {
                        VStack(spacing: Spacing.xs) {
                            Text(title(item))
                                .textStyle(.label)
                                .foregroundStyle(selected ? Palette.ink : Palette.inkTertiary)
                            ZStack {
                                Rectangle().fill(.clear).frame(height: 1)
                                if selected {
                                    Rectangle().fill(Palette.ink).frame(height: 1)
                                        .matchedGeometryEffect(id: "underline", in: underline)
                                }
                            }
                        }
                        .fixedSize()
                        .frame(minHeight: HitTarget.minimum)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, Spacing.screen)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Small outlined label ("For you", "Identified").
struct TagPill: View {
    let text: String

    var body: some View {
        Text(text)
            .textStyle(.label)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.xs)
                    .strokeBorder(Palette.ink.opacity(0.4), lineWidth: 0.75)
            )
    }
}

/// "Myths · 6 min" meta line. Always placed *below* the title.
struct StoryMeta: View {
    let story: Story
    var color: Color = Palette.inkTertiary

    var body: some View {
        Text("\(story.category.title) · \(story.durationLabel)")
            .textStyle(.label)
            .foregroundStyle(color)
            .lineLimit(1)
            .accessibilityLabel("\(story.category.title), \(story.durationMinutes) minutes")
    }
}
