import Foundation

/// Abstraction over the content backend. Features depend on this protocol only,
/// so the mock can be swapped for a networked implementation without UI changes.
protocol StoryProviding: Sendable {
    func featured() async throws -> [Story]
    func allStories() async throws -> [Story]
    func recommendations() async throws -> [Story]
    func story(id: Story.ID) async throws -> Story?
    func related(to story: Story) async throws -> [Story]
}

/// In-memory implementation backed by `MockData`. Simulates latency.
struct MockStoryService: StoryProviding {
    var latency: Duration = .milliseconds(350)

    func featured() async throws -> [Story] {
        try await Task.sleep(for: latency)
        return MockData.stories.filter(\.isRecommended)
    }

    func allStories() async throws -> [Story] {
        try await Task.sleep(for: latency)
        return MockData.stories
    }

    func recommendations() async throws -> [Story] {
        try await Task.sleep(for: latency)
        return MockData.stories.filter(\.isRecommended) + MockData.stories.filter { !$0.isRecommended }
    }

    func story(id: Story.ID) async throws -> Story? {
        MockData.stories.first { $0.id == id }
    }

    func related(to story: Story) async throws -> [Story] {
        MockData.stories.filter { $0.id != story.id }.shuffled().prefix(4).map { $0 }
    }
}
