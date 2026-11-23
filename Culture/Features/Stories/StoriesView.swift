import SwiftUI

/// Browsable, filterable, searchable story catalogue.
struct StoriesView: View {
    enum Filter: Hashable { case all, category(StoryCategory) }

    @Environment(\.services) private var services
    @Environment(LibraryStore.self) private var library
    @Environment(Router.self) private var router
    @State private var stories: Loadable<[Story]> = .loading
    @State private var filter: Filter = .all
    @State private var query = ""

    private var filters: [Filter] { [.all] + StoryCategory.allCases.map(Filter.category) }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                Section {
                    switch stories {
                    case .loading: LoadingView()
                    case .failed(let msg): EmptyStateView(symbol: "book", title: "Couldn't load", message: msg)
                    case .loaded(let all): rows(filtered(all))
                    }
                } header: {
                    ChipBar(items: filters, selection: $filter) { f in
                        switch f {
                        case .all: "All"
                        case .category(let c): c.title
                        }
                    }
                    .padding(.vertical, Spacing.xxs)
                    .background(Palette.background)
                    .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 0.5) }
                }
            }
            .padding(.bottom, Spacing.section)
            .animation(Motion.smooth, value: filter)
            .animation(Motion.smooth, value: query)
        }
        .scrollIndicators(.hidden)
        .screenBackground()
        .navigationTitle("Stories")
        .searchable(text: $query, prompt: "Search myths, places, artifacts")
        .task { await load() }
        .onAppear(perform: applyPendingFilter)
        .onChange(of: router.pendingStoriesFilter) { applyPendingFilter() }
    }

    private func applyPendingFilter() {
        guard let category = router.pendingStoriesFilter else { return }
        filter = .category(category)
        router.pendingStoriesFilter = nil
    }

    @ViewBuilder
    private func rows(_ items: [Story]) -> some View {
        if items.isEmpty {
            EmptyStateView(symbol: "magnifyingglass", title: "No matches", message: "Try another search or theme.")
        } else {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, story in
                StoryLink(story: story) {
                    StoryRow(story: story, isSaved: library.isSaved(story.id)) {
                        library.toggleSaved(story.id)
                    }
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.md)
                .listRowEntrance()
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .overlay(alignment: .bottom) {
                    if index < items.count - 1 {
                        Rectangle().fill(Palette.hairline).frame(height: 0.5)
                            .padding(.horizontal, Spacing.screen)
                    }
                }
            }
        }
    }

    private func filtered(_ all: [Story]) -> [Story] {
        let q = InputSanitizer.clean(query).lowercased()
        return all.filter { story in
            let matchesFilter: Bool = {
                if case .category(let c) = filter { return story.category == c }
                return true
            }()
            let matchesQuery = q.isEmpty
                || story.title.lowercased().contains(q)
                || story.region.lowercased().contains(q)
                || story.subtitle.lowercased().contains(q)
            return matchesFilter && matchesQuery
        }
    }

    private func load() async {
        do { stories = .loaded(try await services.stories.allStories()) }
        catch is CancellationError {}
        catch { stories = .failed("Please try again.") }
    }
}

#Preview { NavigationStack { StoriesView() }.environment(LibraryStore()).environment(Router()).preferredColorScheme(.dark) }
