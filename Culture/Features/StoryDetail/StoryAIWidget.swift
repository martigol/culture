//
//  StoryAIWidget.swift
//  Culture
//
//  Created by Mario Martinelli on 24/11/2026.
//

import SwiftUI

/// Floating AI button on a story (bottom right). Tap it and three actions fan
/// out on an arc:
/// - **mic**: the story read aloud, storyteller style, in the chosen language
/// - **keyboard**: ask questions about the story
/// - **globe**: the language for both reading and answers
/// While reading, the collapsed button's waveform animates and a pill shows progress.
struct StoryAIWidget: View {
    let story: Story
    let player: StoryNarrator
    @Bindable var assistant: StoryAssistant

    @State private var isExpanded: Bool
    @State private var showsAsk = false
    @State private var showsLanguages = false
    @State private var readingError: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let fabSize: CGFloat = 64
    private let actionSize: CGFloat = 56
    /// Distance from the button's centre to each action's centre.
    private let radius: CGFloat = 84

    init(story: Story, player: StoryNarrator, assistant: StoryAssistant, isExpanded: Bool = false) {
        self.story = story
        self.player = player
        self.assistant = assistant
        _isExpanded = State(initialValue: isExpanded)
    }

    private enum Action: CaseIterable {
        case ask, read, language

        /// Position on the arc, in degrees (0 = right, 90 = straight up).
        var angle: Double {
            switch self {
            case .ask: 180
            case .read: 135
            case .language: 90
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isExpanded {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { setExpanded(false) }
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }

            HStack(spacing: Spacing.sm) {
                if !isExpanded, player.isPlaying || assistant.isTranslating {
                    readingPill
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                cluster
            }
            .padding(.trailing, Spacing.screen)
            .padding(.bottom, Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .animation(reduceMotion ? nil : Motion.smooth, value: player.isPlaying)
        .animation(reduceMotion ? nil : Motion.smooth, value: assistant.isTranslating)
        .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
        .sheet(isPresented: $showsAsk) { AskStorySheet(story: story, assistant: assistant) }
        .sheet(isPresented: $showsLanguages) { LanguagePickerSheet(assistant: assistant) }
        .alert("Can't read aloud", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(readingError ?? "")
        }
        .onChange(of: assistant.language) { languageChanged() }
    }

    // MARK: Cluster

    private var cluster: some View {
        ZStack {
            ForEach(Array(Action.allCases.enumerated()), id: \.element) { index, action in
                actionButton(action)
                    .offset(isExpanded ? offset(for: action) : .zero)
                    .scaleEffect(isExpanded ? 1 : 0.4)
                    .opacity(isExpanded ? 1 : 0)
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.15)
                            : .spring(response: 0.42, dampingFraction: 0.7).delay(isExpanded ? Double(index) * 0.045 : 0),
                        value: isExpanded
                    )
                    .allowsHitTesting(isExpanded)
                    .accessibilityHidden(!isExpanded)
            }
            mainButton
        }
        .frame(width: fabSize, height: fabSize)
    }

    private func offset(for action: Action) -> CGSize {
        let radians = action.angle * .pi / 180
        return CGSize(width: cos(radians) * radius, height: -sin(radians) * radius)
    }

    private var mainButton: some View {
        Button { setExpanded(!isExpanded) } label: {
            Image(systemName: isExpanded ? "xmark" : "waveform")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Palette.onAccent)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.variableColor.iterative, options: .repeating, isActive: player.isPlaying && !isExpanded)
                .frame(width: fabSize, height: fabSize)
                .background(Palette.accent, in: Circle())
                .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(isExpanded ? "Close story assistant" : "Story assistant")
        .accessibilityHint(isExpanded ? "" : "Read aloud, ask questions, or change language")
    }

    @ViewBuilder
    private func actionButton(_ action: Action) -> some View {
        let isActive = action == .read && player.isPlaying

        Button { perform(action) } label: {
            ZStack {
                Circle().fill(isActive ? Palette.accent : Palette.surfaceRaised)
                Circle().strokeBorder(isActive ? Color.clear : Palette.hairline, lineWidth: 0.75)
                icon(for: action)
                    .foregroundStyle(isActive ? Palette.onAccent : Palette.ink)
            }
            .frame(width: actionSize, height: actionSize)
            .overlay(alignment: .topTrailing) {
                if action == .language, !assistant.language.isEnglish {
                    Text(assistant.language.shortCode)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Palette.onAccent)
                        .padding(.horizontal, 4)
                        .frame(minHeight: 16)
                        .background(Palette.accent, in: Capsule())
                        .offset(x: 2, y: -2)
                }
            }
            .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label(for: action))
    }

    @ViewBuilder
    private func icon(for action: Action) -> some View {
        switch action {
        case .ask:
            Image(systemName: "keyboard")
                .font(.system(size: 20, weight: .regular))
        case .read:
            if assistant.isTranslating {
                ProgressView().tint(Palette.ink)
            } else {
                Image(systemName: player.isPlaying ? "mic.fill" : "mic")
                    .font(.system(size: 21, weight: .regular))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, options: .repeating, isActive: player.isPlaying)
            }
        case .language:
            Image(systemName: "globe")
                .font(.system(size: 21, weight: .regular))
        }
    }

    private func label(for action: Action) -> String {
        switch action {
        case .ask: "Ask a question about this story"
        case .read: player.isPlaying ? "Pause reading" : "Read the story aloud in \(assistant.language.englishName)"
        case .language: "Language: \(assistant.language.englishName)"
        }
    }

    // MARK: Reading pill

    private var readingPill: some View {
        Button { player.toggle() } label: {
            HStack(spacing: Spacing.sm) {
                if assistant.isTranslating {
                    ProgressView().tint(Palette.ink).controlSize(.small)
                } else {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(assistant.isTranslating ? "Translating…" : "Reading aloud")
                        .textStyle(.callout)
                    Text(pillDetail)
                        .textStyle(.label)
                        .monospacedDigit()
                        .foregroundStyle(Palette.inkTertiary)
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, Spacing.md)
            .frame(minHeight: 48)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 0.75))
        }
        .buttonStyle(.pressable)
        .disabled(assistant.isTranslating)
        .accessibilityLabel(assistant.isTranslating ? "Translating the story" : "Pause reading")
    }

    private var pillDetail: String {
        if assistant.isTranslating { return "into \(assistant.language.nativeName)" }
        return "\(assistant.language.nativeName) · −\(StoryNarrator.format(player.duration - player.elapsed))"
    }

    // MARK: Actions

    private func setExpanded(_ expanded: Bool) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.75)) { isExpanded = expanded }
    }

    private func perform(_ action: Action) {
        setExpanded(false)
        switch action {
        case .ask: showsAsk = true
        case .read: Task { await toggleReading() }
        case .language: showsLanguages = true
        }
    }

    /// Pauses, or reads in the chosen language (translating first if needed).
    private func toggleReading() async {
        if player.isPlaying {
            player.pause()
            return
        }
        if player.languageID != assistant.language.id {
            do {
                let script = try await assistant.narrationScript(for: story)
                player.load(text: script, language: assistant.language.id)
            } catch {
                readingError = error.localizedDescription
                return
            }
        }
        player.play()
    }

    /// Switching language mid-story restarts the reading in the new language.
    private func languageChanged() {
        guard player.isPlaying else { return }
        player.stop()
        Task { await toggleReading() }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { readingError != nil }, set: { if !$0 { readingError = nil } })
    }
}

// MARK: - Ask

/// Chat about the story, answered on device in the chosen language.
struct AskStorySheet: View {
    let story: Story
    @Bindable var assistant: StoryAssistant

    @State private var draft = ""
    @FocusState private var isFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.md) {
                        if assistant.messages.isEmpty { intro }
                        ForEach(assistant.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(Spacing.screen)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: assistant.messages.last?.text) {
                    guard let last = assistant.messages.last else { return }
                    withAnimation(Motion.smooth) { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            inputBar
        }
        .background(Palette.surface)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.surface)
        .onAppear { isFocused = true }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Ask about \(story.title)")
                    .textStyle(.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Label("Answers in \(assistant.language.nativeName) · on device", systemImage: "globe")
                    .textStyle(.label)
                    .foregroundStyle(Palette.inkTertiary)
            }
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Palette.ink)
                    .frame(width: HitTarget.minimum, height: HitTarget.minimum)
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.sm)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 0.5) }
    }

    @ViewBuilder
    private var intro: some View {
        if let reason = assistant.unavailableReason {
            Label(reason, systemImage: "sparkles")
                .textStyle(.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .padding(Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.75))
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Curious about something? Ask away.")
                    .textStyle(.callout)
                    .foregroundStyle(Palette.inkSecondary)
                ForEach(assistant.suggestions, id: \.self) { suggestion in
                    Button { send(suggestion) } label: {
                        Text(suggestion)
                            .textStyle(.callout)
                            .foregroundStyle(Palette.ink)
                            .padding(.horizontal, Spacing.md)
                            .frame(minHeight: HitTarget.minimum)
                            .overlay(Capsule().strokeBorder(Palette.ink.opacity(0.3), lineWidth: 0.75))
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Ask a question…", text: $draft)
                .textStyle(.body)
                .foregroundStyle(Palette.ink)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit { send(draft) }
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 46)
                .background(Palette.surfaceRaised, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 0.75))

            Button {
                if assistant.isAnswering { assistant.stopAnswering() } else { send(draft) }
            } label: {
                Image(systemName: assistant.isAnswering ? "stop.fill" : "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.onAccent)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 46, height: 46)
                    .background(Palette.accent, in: Circle())
            }
            .buttonStyle(.pressable)
            .disabled(!assistant.isAnswering && draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(!assistant.isAnswering && draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            .accessibilityLabel(assistant.isAnswering ? "Stop answering" : "Send")
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.vertical, Spacing.sm)
        .background(Palette.surface)
        .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 0.5) }
    }

    private func send(_ text: String) {
        guard !assistant.isAnswering else { return }
        assistant.ask(text)
        draft = ""
    }
}

private struct MessageBubble: View {
    let message: StoryAssistant.Message

    var body: some View {
        let isUser = message.role == .user
        HStack {
            if isUser { Spacer(minLength: Spacing.xxl) }
            Group {
                if message.text.isEmpty {
                    ProgressView()
                        .tint(Palette.inkSecondary)
                        .frame(width: 44, height: 22)
                        .accessibilityLabel("Thinking")
                } else {
                    Text(message.text)
                        .textStyle(.body)
                        .foregroundStyle(isUser ? Palette.onAccent : Palette.ink)
                        .textSelection(.enabled)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(isUser ? Palette.accent : Palette.surfaceRaised,
                        in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            if !isUser { Spacer(minLength: Spacing.xxl) }
        }
    }
}

// MARK: - Language

/// One language for reading aloud and for answers.
struct LanguagePickerSheet: View {
    @Bindable var assistant: StoryAssistant
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(StoryLanguage.all) { language in
                        row(language)
                    }
                } footer: {
                    Text("Stories are read aloud and questions answered in this language. Translation happens on your device.")
                }
                .listRowBackground(Palette.surfaceRaised)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.surface)
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Palette.surface)
    }

    private func row(_ language: StoryLanguage) -> some View {
        let isSupported = assistant.supports(language)
        let isSelected = language == assistant.language

        return Button {
            assistant.language = language
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.nativeName)
                        .textStyle(.callout)
                        .foregroundStyle(isSupported ? Palette.ink : Palette.inkTertiary)
                    Text(isSupported ? language.englishName
                         : "\(language.englishName) · \(assistant.isModelAvailable ? "not available yet" : "needs Apple Intelligence")")
                        .textStyle(.label)
                        .foregroundStyle(Palette.inkTertiary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(!isSupported)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("Collapsed") {
    let story = MockData.story("parthenon")!
    let player = StoryNarrator()
    player.load(story)
    return StoryAIWidget(story: story, player: player, assistant: StoryAssistant())
        .screenBackground()
        .previewEnvironment()
}

#Preview("Expanded") {
    let story = MockData.story("parthenon")!
    let player = StoryNarrator()
    player.load(story)
    return NavigationStack {
        StoryDetailView(storyID: "parthenon").appDestinations()
    }
    .overlay { StoryAIWidget(story: story, player: player, assistant: StoryAssistant(), isExpanded: true) }
    .previewEnvironment()
}

#Preview("Ask") {
    let story = MockData.story("parthenon")!
    let assistant = StoryAssistant()
    assistant.load(story)
    return AskStorySheet(story: story, assistant: assistant)
        .previewEnvironment()
}

#Preview("Language") {
    LanguagePickerSheet(assistant: StoryAssistant())
        .previewEnvironment()
}
