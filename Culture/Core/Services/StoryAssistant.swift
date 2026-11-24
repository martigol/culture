//
//  StoryAssistant.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import Foundation
import FoundationModels
import Observation

/// A language the story can be read aloud and answered in.
struct StoryLanguage: Identifiable, Hashable, Sendable {
    /// BCP-47, e.g. "el-GR". Also picks the narration voice.
    let id: String
    /// Name used in prompts ("Greek").
    let englishName: String

    /// Name in the language itself ("Ελληνικά").
    var nativeName: String {
        let locale = Locale(identifier: id)
        return locale.localizedString(forLanguageCode: id)?.capitalized(with: locale) ?? englishName
    }

    /// "EL"
    var shortCode: String { String(id.prefix { $0 != "-" }).uppercased() }
    var isEnglish: Bool { id.hasPrefix("en") }

    static let english = StoryLanguage(id: "en-GB", englishName: "English")

    static let all: [StoryLanguage] = [
        english,
        StoryLanguage(id: "el-GR", englishName: "Greek"),
        StoryLanguage(id: "it-IT", englishName: "Italian"),
        StoryLanguage(id: "fr-FR", englishName: "French"),
        StoryLanguage(id: "es-ES", englishName: "Spanish"),
        StoryLanguage(id: "de-DE", englishName: "German"),
        StoryLanguage(id: "pt-BR", englishName: "Portuguese"),
        StoryLanguage(id: "nl-NL", englishName: "Dutch"),
        StoryLanguage(id: "tr-TR", englishName: "Turkish"),
        StoryLanguage(id: "ja-JP", englishName: "Japanese"),
        StoryLanguage(id: "ko-KR", englishName: "Korean"),
        StoryLanguage(id: "zh-CN", englishName: "Chinese"),
    ]
}

/// The story page's AI: answers questions about a story and translates it for
/// narration, in the user's chosen language. Runs on the on-device model
/// (Apple Intelligence, iOS 26+), so nothing leaves the phone. On older systems
/// it explains why instead, and English narration still works.
@Observable
@MainActor
final class StoryAssistant {
    struct Message: Identifiable, Equatable {
        enum Role { case user, assistant }
        let id = UUID()
        let role: Role
        var text: String
    }

    enum AssistantError: LocalizedError {
        case unavailable(String)
        var errorDescription: String? {
            switch self { case .unavailable(let reason): reason }
        }
    }

    private(set) var messages: [Message] = []
    private(set) var isAnswering = false
    private(set) var isTranslating = false

    /// Used for reading aloud and for answers. Remembered across launches.
    var language: StoryLanguage {
        didSet {
            guard language != oldValue else { return }
            UserDefaults.standard.set(language.id, forKey: Self.languageKey)
            session = nil // new instructions in the new language
        }
    }

    @ObservationIgnored private var story: Story?
    /// A `LanguageModelSession` (typed loosely so the app still deploys to iOS 17).
    @ObservationIgnored private var session: AnyObject?
    @ObservationIgnored private var answerTask: Task<Void, Never>?
    /// "storyID|languageID" → translated narration script.
    @ObservationIgnored private var translations: [String: String] = [:]

    private static let languageKey = "storyLanguage"

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.languageKey)
        language = StoryLanguage.all.first { $0.id == saved } ?? .english
    }

    // MARK: Availability

    var isModelAvailable: Bool { unavailableReason == nil }

    /// Why questions/translation can't run, phrased for the user.
    var unavailableReason: String? {
        guard #available(iOS 26.0, *) else {
            return "Questions and translations need iOS 26 or later with Apple Intelligence."
        }
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to ask questions and hear stories in other languages."
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence, so questions and translations aren't available."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still getting ready. Try again in a little while."
        case .unavailable:
            return "On-device AI isn't available right now."
        }
    }

    /// English always works (the original text); other languages need the model to support them.
    func supports(_ language: StoryLanguage) -> Bool {
        if language.isEnglish { return true }
        guard #available(iOS 26.0, *), isModelAvailable else { return false }
        return SystemLanguageModel.default.supportsLocale(Locale(identifier: language.id))
    }

    // MARK: Story

    /// Switches to `story`, clearing the conversation if it's a different one.
    func load(_ story: Story) {
        guard self.story?.id != story.id else { return }
        answerTask?.cancel()
        self.story = story
        messages = []
        session = nil
        isAnswering = false
    }

    // MARK: Questions

    /// Questions to get started, shown before the first message.
    var suggestions: [String] {
        guard let story else { return [] }
        return ["What happened at \(story.title)?", "Why does it matter today?", "Tell me a little-known fact"]
    }

    /// Sends a question and streams the answer into `messages`.
    func ask(_ raw: String) {
        let question = InputSanitizer.clean(raw, maxLength: 300)
        guard !question.isEmpty, !isAnswering, let story else { return }
        messages.append(Message(role: .user, text: question))

        guard #available(iOS 26.0, *), unavailableReason == nil else {
            messages.append(Message(role: .assistant, text: unavailableReason ?? ""))
            return
        }

        let session = (session as? LanguageModelSession) ?? makeSession(for: story)
        self.session = session
        let answer = Message(role: .assistant, text: "")
        messages.append(answer)
        isAnswering = true

        answerTask = Task { [weak self] in
            do {
                for try await snapshot in session.streamResponse(to: question) {
                    self?.update(answer.id, with: snapshot.content)
                }
            } catch is CancellationError {
                // Story changed or sheet closed.
            } catch {
                self?.update(answer.id, with: self?.message(for: error) ?? "")
            }
            self?.isAnswering = false
        }
    }

    func stopAnswering() {
        answerTask?.cancel()
        isAnswering = false
    }

    private func update(_ id: Message.ID, with text: String) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text = text
    }

    @available(iOS 26.0, *)
    private func makeSession(for story: Story) -> LanguageModelSession {
        // Keep the story well inside the on-device context window.
        let body = String(story.body.prefix(5_000))
        return LanguageModelSession(instructions: """
            You are a warm, knowledgeable guide in Culture, an app about ancient Greek myths, places and artifacts.
            Answer the visitor's questions about the story below, and about its history, mythology, art and site.
            Keep answers short: two to four sentences of plain prose, no lists, no markdown.
            If the story doesn't cover something, use general historical knowledge and say when something is legend or uncertain.
            Politely decline questions unrelated to culture, history or this story.
            Always answer in \(language.englishName), whatever language the question is written in.

            Story: \(story.title) — \(story.subtitle)
            Place: \(story.region). Era: \(story.era).
            \(story.summary)

            \(body)
            """)
    }

    private func message(for error: Error) -> String {
        if #available(iOS 26.0, *), let error = error as? LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                session = nil // start a fresh conversation next time
                return "That conversation got long, so I've cleared my memory of it. Ask again?"
            case .guardrailViolation, .refusal:
                return "I can't help with that one. Try asking about the story, the site or its history."
            case .unsupportedLanguageOrLocale:
                return "I can't answer in \(language.englishName) yet. Pick another language with the globe."
            default:
                break
            }
        }
        Log.app.error("Assistant failed: \(error.localizedDescription)")
        return "Something went wrong answering that. Please try again."
    }

    // MARK: Narration

    /// The narration script for `story` in the current language. English is
    /// the original; other languages are translated on device (and cached).
    func narrationScript(for story: Story) async throws -> String {
        let original = StoryNarrator.script(for: story)
        let language = language
        guard !language.isEnglish else { return original }

        let key = "\(story.id)|\(language.id)"
        if let cached = translations[key] { return cached }
        guard #available(iOS 26.0, *), unavailableReason == nil else {
            throw AssistantError.unavailable(unavailableReason ?? "")
        }
        guard supports(language) else {
            throw AssistantError.unavailable("Stories can't be read in \(language.englishName) on this device yet.")
        }

        isTranslating = true
        defer { isTranslating = false }

        let instructions = """
            You are a literary translator. Translate the text into \(language.englishName).
            Keep the meaning, tone, names and paragraph breaks. Reply with the translation only.
            """
        var parts: [String] = []
        // A fresh session per chunk keeps each request small.
        for chunk in Self.chunks(of: original, maxLength: 1_400) {
            let response = try await LanguageModelSession(instructions: instructions).respond(to: chunk)
            parts.append(response.content.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let translated = parts.joined(separator: "\n\n")
        translations[key] = translated
        return translated
    }

    /// Splits on paragraph breaks into pieces of at most ~`maxLength` characters.
    private static func chunks(of text: String, maxLength: Int) -> [String] {
        var chunks: [String] = []
        var current = ""
        for paragraph in text.components(separatedBy: "\n\n") where !paragraph.isEmpty {
            if !current.isEmpty, current.count + paragraph.count > maxLength {
                chunks.append(current)
                current = ""
            }
            current += current.isEmpty ? paragraph : "\n\n" + paragraph
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
