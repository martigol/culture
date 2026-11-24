import SwiftUI

/// Quick summary shown after a successful scan (Scan → Summary → Story).
struct ScanResultSheet: View {
    let story: Story
    var pinnedPhoto: SitePhoto? = nil
    var onOpen: () -> Void
    var onRescan: () -> Void
    var onShowOnMap: () -> Void = {}

    @Environment(LibraryStore.self) private var library

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            HStack(alignment: .top, spacing: Spacing.md) {
                ArtworkView(artwork: story.artwork)
                    .frame(width: 88, height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.xs, style: .continuous))
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(story.title)
                        .textStyle(.title)
                        .foregroundStyle(Palette.ink)
                    Text("\(story.region) · \(story.era)")
                        .textStyle(.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                    Label("Identified", systemImage: "checkmark.circle")
                        .textStyle(.footnote)
                        .foregroundStyle(Palette.inkTertiary)
                        .padding(.top, Spacing.xxs)
                    if let pinnedPhoto {
                        Button(action: onShowOnMap) {
                            Label(pinnedPhoto.isLocationApproximate ? "Photo pinned to the site" : "Photo pinned to your map",
                                  systemImage: "mappin.and.ellipse")
                                .textStyle(.footnote)
                                .foregroundStyle(Palette.inkSecondary)
                                .underline()
                        }
                        .frame(minHeight: HitTarget.minimum, alignment: .leading)
                        .transition(.opacity)
                        .accessibilityHint("Opens your map")
                    }
                }
            }

            OrnamentRule()

            Text(story.summary)
                .textStyle(.lede)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            VStack(spacing: Spacing.sm) {
                Button("Read the full story", action: onOpen)
                    .buttonStyle(.primary)
                HStack(spacing: Spacing.sm) {
                    Button(library.isSaved(story.id) ? "Saved" : "Save") {
                        library.toggleSaved(story.id)
                    }
                    .buttonStyle(.secondary)
                    Button("Scan again", action: onRescan)
                        .buttonStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.md)
        .animation(Motion.smooth, value: pinnedPhoto)
        .presentationDetents([.height(540), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Radius.lg)
        .presentationBackground(Palette.surface)
    }
}

#Preview {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            ScanResultSheet(story: MockData.story("agamemnon")!, onOpen: {}, onRescan: {})
        }
        .previewEnvironment()
}

#Preview("Photo pinned") {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            ScanResultSheet(story: MockData.story("parthenon")!, pinnedPhoto: PhotoStore.preview.photos.first,
                            onOpen: {}, onRescan: {})
        }
        .previewEnvironment()
}
